package br.com.puc.so_mais_uma.integracao.pix.inter;

import br.com.puc.so_mais_uma.exception.IntegracaoExternaException;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import org.springframework.http.MediaType;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

/**
 * Token OAuth2 {@code client_credentials} do Inter, mantido apenas em memória e reutilizado
 * enquanto vale (limite de 5 obtenções por minuto). A obtenção é sincronizada para que requisições
 * concorrentes não peçam vários tokens ao mesmo tempo.
 */
public class InterTokenService {

    /** Margem para renovar antes do vencimento real. */
    private static final Duration MARGEM = Duration.ofMinutes(5);
    private static final Duration VALIDADE_MAXIMA = Duration.ofHours(1);

    private final RestClient http;
    private final String clientId;
    private final String clientSecret;
    private final String escopos;
    private final Clock relogio;

    private String token;
    private Instant validoAte = Instant.MIN;

    public InterTokenService(RestClient http, String clientId, String clientSecret, String escopos, Clock relogio) {
        this.http = http;
        this.clientId = clientId;
        this.clientSecret = clientSecret;
        this.escopos = escopos;
        this.relogio = relogio;
    }

    public synchronized String obter() {
        if (token != null && relogio.instant().isBefore(validoAte)) {
            return token;
        }
        MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        form.add("client_id", clientId);
        form.add("client_secret", clientSecret);
        form.add("grant_type", "client_credentials");
        form.add("scope", escopos);
        RespostaToken resposta;
        try {
            resposta = http.post().uri("/oauth/v2/token")
                    .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                    .body(form)
                    .retrieve()
                    .body(RespostaToken.class);
        } catch (RestClientException e) {
            // Nunca inclui o corpo do pedido: ele contém o client_secret.
            throw new IntegracaoExternaException("Falha ao obter token do Inter: " + e.getClass().getSimpleName(), e);
        }
        if (resposta == null || resposta.accessToken() == null) {
            throw new IntegracaoExternaException("Resposta de token do Inter sem access_token");
        }
        Duration validade = resposta.expiresIn() > 0 ? Duration.ofSeconds(resposta.expiresIn()) : VALIDADE_MAXIMA;
        if (validade.compareTo(VALIDADE_MAXIMA) > 0) {
            validade = VALIDADE_MAXIMA;
        }
        token = resposta.accessToken();
        validoAte = relogio.instant().plus(validade.minus(MARGEM));
        return token;
    }

    /** Descarta o token em cache (após 401 do Inter). */
    public synchronized void invalidar() {
        token = null;
        validoAte = Instant.MIN;
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    record RespostaToken(@JsonProperty("access_token") String accessToken, @JsonProperty("expires_in") long expiresIn) {}
}
