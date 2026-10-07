package br.com.puc.so_mais_uma.integracao.pix.inter;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import br.com.puc.so_mais_uma.exception.IntegracaoExternaException;
import br.com.puc.so_mais_uma.integracao.pix.PixGateway.CobrancaPix;
import br.com.puc.so_mais_uma.integracao.pix.PixGateway.Situacao;
import br.com.puc.so_mais_uma.integracao.pix.PixGateway.StatusCobranca;
import br.com.puc.so_mais_uma.support.RelogioAjustavel;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.math.BigDecimal;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.List;
import java.util.Map;
import java.util.Queue;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import javax.net.ssl.SSLHandshakeException;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.web.client.RestClient;

/** API Pix do Inter simulada por um servidor HTTP local (sem mTLS, que é responsabilidade da configuração). */
class InterPixGatewayTest {

    private static final String TXID = "3f9c2b7e1d4a4c6f9a8b7c6d5e4f3a2b";

    private HttpServer server;
    private final List<String> chamadas = new CopyOnWriteArrayList<>();
    private final List<String> corpos = new CopyOnWriteArrayList<>();
    private final Map<String, Queue<Resposta>> respostas = new ConcurrentHashMap<>();
    private final RelogioAjustavel relogio = new RelogioAjustavel(Instant.parse("2026-10-10T12:00:00Z"));
    private InterPixGateway gateway;

    private record Resposta(int status, String corpo) {}

    @BeforeEach
    void iniciar() throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/", this::atender);
        server.start();
        responder("POST /oauth/v2/token", 200, "{\"access_token\":\"tk\",\"token_type\":\"Bearer\",\"expires_in\":3600}");
        RestClient http = RestClient.builder().baseUrl("http://127.0.0.1:" + server.getAddress().getPort()).build();
        InterTokenService tokens = new InterTokenService(http, "id", "segredo", "cob.write cob.read", relogio);
        gateway = new InterPixGateway(http, tokens, "chave-pix-plataforma");
    }

    @AfterEach
    void parar() {
        server.stop(0);
    }

    /** Enfileira respostas para "MÉTODO caminho"; a última se repete. */
    private void responder(String rota, int status, String corpo) {
        respostas.computeIfAbsent(rota, r -> new ArrayDeque<>()).add(new Resposta(status, corpo));
    }

    private void atender(HttpExchange troca) throws IOException {
        String rota = troca.getRequestMethod() + " " + troca.getRequestURI().getPath();
        chamadas.add(rota + " auth=" + troca.getRequestHeaders().getFirst("Authorization"));
        corpos.add(new String(troca.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
        Queue<Resposta> fila = respostas.get(rota);
        Resposta r = fila == null ? new Resposta(404, "{}") : fila.size() > 1 ? fila.poll() : fila.peek();
        byte[] bytes = r.corpo().getBytes(StandardCharsets.UTF_8);
        troca.getResponseHeaders().add("Content-Type", "application/json");
        troca.sendResponseHeaders(r.status(), r.status() == 204 ? -1 : bytes.length);
        if (r.status() != 204) {
            troca.getResponseBody().write(bytes);
        }
        troca.close();
    }

    private long chamadasDe(String prefixo) {
        return chamadas.stream().filter(c -> c.startsWith(prefixo)).count();
    }

    @Test
    void criaCobrancaComExpiracaoValorEChaveSemDevedor() {
        responder("PUT /pix/v2/cob/" + TXID, 201, """
                {"txid":"%s","status":"ATIVA","location":"qrcodepix-h.bancointer.com.br/v2/cob/abc",
                 "pixCopiaECola":"00020126...6304ABCD"}""".formatted(TXID));

        CobrancaPix cobranca = gateway.criarCobranca(TXID, new BigDecimal("80"), 900, "Reserva 42");

        assertThat(cobranca.pixCopiaECola()).isEqualTo("00020126...6304ABCD");
        assertThat(cobranca.location()).contains("bancointer");
        String corpo = corpos.get(chamadas.indexOf(chamadas.stream()
                .filter(c -> c.startsWith("PUT")).findFirst().orElseThrow()));
        assertThat(corpo).contains("\"expiracao\":900").contains("\"original\":\"80.00\"")
                .contains("\"chave\":\"chave-pix-plataforma\"").doesNotContain("devedor");
        assertThat(chamadas).anyMatch(c -> c.startsWith("PUT") && c.endsWith("auth=Bearer tk"));
    }

    @Test
    void tokenEReutilizadoEnquantoVale() {
        responder("PUT /pix/v2/cob/" + TXID, 201, "{\"status\":\"ATIVA\",\"pixCopiaECola\":\"x\"}");

        gateway.criarCobranca(TXID, BigDecimal.TEN, 900, "a");
        gateway.criarCobranca(TXID, BigDecimal.TEN, 900, "b");

        assertThat(chamadasDe("POST /oauth/v2/token")).isEqualTo(1);
    }

    @Test
    void consultaConcluidaTrazEndToEndValorEHorario() {
        responder("GET /pix/v2/cob/" + TXID, 200, """
                {"txid":"%s","status":"CONCLUIDA","pix":[{"endToEndId":"E00416968202610081707s0a1b2c3d4e5",
                 "valor":"80.00","horario":"2026-10-08T17:07:40.00-03:00","infoPagador":"x"}]}""".formatted(TXID));

        StatusCobranca status = gateway.consultar(TXID);

        assertThat(status.situacao()).isEqualTo(Situacao.CONCLUIDA);
        assertThat(status.endToEndId()).isEqualTo("E00416968202610081707s0a1b2c3d4e5");
        assertThat(status.valorPago()).isEqualByComparingTo("80.00");
        assertThat(status.pagoEm()).isEqualTo(Instant.parse("2026-10-08T20:07:40Z"));
    }

    @Test
    void mapeiaStatusAtivaERemovidas() {
        responder("GET /pix/v2/cob/" + TXID, 200, "{\"status\":\"ATIVA\"}");
        responder("GET /pix/v2/cob/" + TXID, 200, "{\"status\":\"REMOVIDA_PELO_USUARIO_RECEBEDOR\"}");
        responder("GET /pix/v2/cob/" + TXID, 200, "{\"status\":\"REMOVIDA_PELO_PSP\"}");

        assertThat(gateway.consultar(TXID).situacao()).isEqualTo(Situacao.ATIVA);
        assertThat(gateway.consultar(TXID).situacao()).isEqualTo(Situacao.REMOVIDA_PELO_RECEBEDOR);
        assertThat(gateway.consultar(TXID).situacao()).isEqualTo(Situacao.REMOVIDA_PELO_PSP);
    }

    @Test
    void cobrancaInexistenteNoProvedorContaComoRemovida() {
        assertThat(gateway.consultar("naoexiste000000000000000000000000").situacao())
                .isEqualTo(Situacao.REMOVIDA_PELO_PSP);
    }

    @Test
    void removeCobrancaComPatchDeStatus() {
        responder("PATCH /pix/v2/cob/" + TXID, 200, "{\"status\":\"REMOVIDA_PELO_USUARIO_RECEBEDOR\"}");

        gateway.removerCobranca(TXID);

        assertThat(chamadasDe("PATCH /pix/v2/cob/" + TXID)).isEqualTo(1);
        assertThat(corpos).anyMatch(c -> c.contains("\"status\":\"REMOVIDA_PELO_USUARIO_RECEBEDOR\""));
    }

    @Test
    void limiteExcedidoViraExcecaoPropriaParaPularOCiclo() {
        responder("GET /pix/v2/cob/" + TXID, 429, "{\"title\":\"Too Many Requests\"}");

        assertThatThrownBy(() -> gateway.consultar(TXID)).isInstanceOf(LimiteExcedidoException.class);
    }

    @Test
    void tokenInvalidoRenovaOCacheETentaUmaUnicaVez() {
        responder("GET /pix/v2/cob/" + TXID, 401, "{}");
        responder("GET /pix/v2/cob/" + TXID, 200, "{\"status\":\"ATIVA\"}");

        assertThat(gateway.consultar(TXID).situacao()).isEqualTo(Situacao.ATIVA);
        assertThat(chamadasDe("POST /oauth/v2/token")).isEqualTo(2);
        assertThat(chamadasDe("GET /pix/v2/cob/")).isEqualTo(2);
    }

    @Test
    void tokenInvalidoDuasVezesDesisteComErroDeIntegracao() {
        responder("GET /pix/v2/cob/" + TXID, 401, "{}");

        assertThatThrownBy(() -> gateway.consultar(TXID)).isInstanceOf(IntegracaoExternaException.class);
        assertThat(chamadasDe("GET /pix/v2/cob/")).isEqualTo(2);
    }

    @Test
    void erroDoProvedorViraErroDeIntegracao() {
        responder("PUT /pix/v2/cob/" + TXID, 503, "{}");

        assertThatThrownBy(() -> gateway.criarCobranca(TXID, BigDecimal.TEN, 900, "x"))
                .isInstanceOf(IntegracaoExternaException.class)
                .isNotInstanceOf(LimiteExcedidoException.class);
    }

    @Test
    void certificadoExpiradoViraErroDeIntegracaoSemVazarCredencial() {
        RestClient semTls = RestClient.builder()
                .baseUrl("https://127.0.0.1:1")
                .requestFactory((uri, metodo) -> {
                    throw new IOException(new SSLHandshakeException("PKIX: certificate expired"));
                })
                .build();
        InterTokenService tokens = new InterTokenService(semTls, "id", "segredo-super-secreto", "cob.write", relogio);
        InterPixGateway comCertificadoVencido = new InterPixGateway(semTls, tokens, "chave");

        assertThatThrownBy(() -> comCertificadoVencido.criarCobranca(TXID, BigDecimal.TEN, 900, "x"))
                .isInstanceOf(IntegracaoExternaException.class)
                .satisfies(e -> assertThat(e.getMessage()).doesNotContain("segredo-super-secreto"));
    }

    @Test
    void simulacaoDoSandboxPagaComValorNumerico() {
        responder("POST /pix/v2/cob/pagar/" + TXID, 200, "{\"e2e\":\"E123\"}");

        gateway.simularPagamento(TXID, new BigDecimal("80.00"));

        assertThat(corpos).anyMatch(c -> c.contains("\"valor\":80.0"));
    }
}
