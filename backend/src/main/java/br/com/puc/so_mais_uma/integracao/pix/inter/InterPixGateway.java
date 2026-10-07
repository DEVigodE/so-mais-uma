package br.com.puc.so_mais_uma.integracao.pix.inter;

import br.com.puc.so_mais_uma.entity.ProvedorPagamento;
import br.com.puc.so_mais_uma.exception.IntegracaoExternaException;
import br.com.puc.so_mais_uma.integracao.pix.PixGateway;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import javax.net.ssl.SSLException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClientResponseException;

/**
 * API Pix do Banco Inter (cobrança imediata {@code cob}), com mTLS e token OAuth2. Nunca envia
 * dados do pagador ({@code devedor}) e nunca registra corpo de resposta ou credencial no log.
 */
public class InterPixGateway implements PixGateway {

    private static final Logger log = LoggerFactory.getLogger(InterPixGateway.class);

    private final RestClient http;
    private final InterTokenService tokens;
    private final String chave;

    public InterPixGateway(RestClient http, InterTokenService tokens, String chave) {
        this.http = http;
        this.tokens = tokens;
        this.chave = chave;
    }

    @Override
    public CobrancaPix criarCobranca(String txid, BigDecimal valor, int expiracaoSegundos, String descricao) {
        Map<String, Object> corpo = Map.of(
                "calendario", Map.of("expiracao", expiracaoSegundos),
                "valor", Map.of("original", valor.setScale(2, RoundingMode.HALF_UP).toPlainString()),
                "chave", chave,
                "solicitacaoPagador", descricao);
        RespostaCobranca r = executar("criar cobrança " + txid, token -> http.put()
                .uri("/pix/v2/cob/{txid}", txid)
                .header("Authorization", "Bearer " + token)
                .body(corpo)
                .retrieve()
                .body(RespostaCobranca.class));
        if (r == null || r.pixCopiaECola() == null) {
            throw new IntegracaoExternaException("Cobrança " + txid + " criada sem pixCopiaECola");
        }
        return new CobrancaPix(r.pixCopiaECola(), r.location());
    }

    @Override
    public StatusCobranca consultar(String txid) {
        RespostaCobranca r;
        try {
            r = executar("consultar cobrança " + txid, token -> http.get()
                    .uri("/pix/v2/cob/{txid}", txid)
                    .header("Authorization", "Bearer " + token)
                    .retrieve()
                    .body(RespostaCobranca.class));
        } catch (IntegracaoExternaException e) {
            if (e.getCause() instanceof RestClientResponseException rre && rre.getStatusCode().value() == 404) {
                return new StatusCobranca(Situacao.REMOVIDA_PELO_PSP, null, null, null);
            }
            throw e;
        }
        return mapear(r);
    }

    @Override
    public void removerCobranca(String txid) {
        executar("remover cobrança " + txid, token -> http.patch()
                .uri("/pix/v2/cob/{txid}", txid)
                .header("Authorization", "Bearer " + token)
                .body(Map.of("status", "REMOVIDA_PELO_USUARIO_RECEBEDOR"))
                .retrieve()
                .toBodilessEntity());
    }

    /** Endpoint exclusivo do sandbox: registra o pagamento da cobrança. */
    @Override
    public void simularPagamento(String txid, BigDecimal valor) {
        executar("simular pagamento " + txid, token -> http.post()
                .uri("/pix/v2/cob/pagar/{txid}", txid)
                .header("Authorization", "Bearer " + token)
                // Número JSON, como o Inter espera (BigDecimal sairia como string pelo JacksonConfig).
                .body(Map.of("valor", valor.setScale(2, RoundingMode.HALF_UP).doubleValue()))
                .retrieve()
                .toBodilessEntity());
    }

    @Override
    public ProvedorPagamento provedor() {
        return ProvedorPagamento.INTER;
    }

    static StatusCobranca mapear(RespostaCobranca r) {
        if (r == null || r.status() == null) {
            throw new IntegracaoExternaException("Consulta de cobrança sem status");
        }
        return switch (r.status()) {
            case "CONCLUIDA" -> {
                Pix pix = r.pix() == null || r.pix().isEmpty() ? null : r.pix().getFirst();
                yield pix == null ? new StatusCobranca(Situacao.CONCLUIDA, null, null, null)
                        : new StatusCobranca(Situacao.CONCLUIDA, pix.endToEndId(),
                                pix.valor() == null ? null : new BigDecimal(pix.valor()), horario(pix.horario()));
            }
            case "REMOVIDA_PELO_USUARIO_RECEBEDOR" -> new StatusCobranca(Situacao.REMOVIDA_PELO_RECEBEDOR, null, null, null);
            case "REMOVIDA_PELO_PSP" -> new StatusCobranca(Situacao.REMOVIDA_PELO_PSP, null, null, null);
            default -> new StatusCobranca(Situacao.ATIVA, null, null, null);
        };
    }

    private static Instant horario(String texto) {
        try {
            return texto == null ? null : OffsetDateTime.parse(texto).toInstant();
        } catch (RuntimeException e) {
            return null;
        }
    }

    /**
     * Executa com o token atual. 401 invalida o cache e tenta uma única vez; 429 vira
     * {@link LimiteExcedidoException}; certificado inválido ou expirado e demais falhas viram
     * {@link IntegracaoExternaException}.
     */
    private <T> T executar(String operacao, Function<String, T> chamada) {
        try {
            try {
                return chamada.apply(tokens.obter());
            } catch (RestClientResponseException e) {
                if (e.getStatusCode().value() != 401) {
                    throw e;
                }
                log.info("Inter respondeu 401 ao {}; renovando o token e tentando uma vez", operacao);
                tokens.invalidar();
                return chamada.apply(tokens.obter());
            }
        } catch (RestClientResponseException e) {
            int status = e.getStatusCode().value();
            if (status == 429) {
                throw new LimiteExcedidoException("Limite de chamadas do Inter excedido ao " + operacao);
            }
            log.error("Inter respondeu {} ao {}", status, operacao);
            throw new IntegracaoExternaException("Inter respondeu " + status + " ao " + operacao, e);
        } catch (ResourceAccessException e) {
            if (causaSsl(e)) {
                log.error("Falha de TLS com o Inter ao {}: verifique se o certificado expirou", operacao);
                throw new IntegracaoExternaException("Certificado do Inter inválido ou expirado", e);
            }
            log.warn("Inter indisponível ao {}: {}", operacao, e.getClass().getSimpleName());
            throw new IntegracaoExternaException("Inter indisponível ao " + operacao, e);
        } catch (RestClientException e) {
            throw new IntegracaoExternaException("Falha ao " + operacao, e);
        }
    }

    private static boolean causaSsl(Throwable e) {
        for (Throwable t = e; t != null; t = t.getCause()) {
            if (t instanceof SSLException) {
                return true;
            }
        }
        return false;
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    record RespostaCobranca(String txid, String status, String location, String pixCopiaECola, List<Pix> pix) {}

    @JsonIgnoreProperties(ignoreUnknown = true)
    record Pix(String endToEndId, String valor, String horario) {}
}
