package br.com.puc.so_mais_uma;

import static org.assertj.core.api.Assertions.assertThat;

import br.com.puc.so_mais_uma.integracao.pix.PixGateway;
import br.com.puc.so_mais_uma.integracao.pix.inter.InterPixGateway;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.security.cert.Certificate;
import java.util.Base64;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.ApplicationContext;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.postgresql.PostgreSQLContainer;

/**
 * Superfície exposta por ambiente (capability plataforma-backend, design.md D7): sobe a aplicação
 * nos ambientes integrados com um certificado autoassinado gerado na hora (nada é versionado).
 */
class AmbientesIT {

    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = IntegracaoTestBase.POSTGRES;

    private static final Path CERT;
    private static final Path CHAVE;

    static {
        try {
            Path dir = Files.createTempDirectory("inter-teste");
            Path p12 = dir.resolve("teste.p12");
            Process keytool = new ProcessBuilder(Path.of(System.getProperty("java.home"), "bin", "keytool").toString(),
                    "-genkeypair", "-alias", "inter", "-keyalg", "RSA", "-keysize", "2048", "-validity", "2",
                    "-dname", "CN=teste", "-storetype", "PKCS12", "-keystore", p12.toString(),
                    "-storepass", "senha1", "-keypass", "senha1").inheritIO().start();
            if (keytool.waitFor() != 0) {
                throw new IllegalStateException("keytool falhou");
            }
            KeyStore ks = KeyStore.getInstance("PKCS12");
            try (var in = Files.newInputStream(p12)) {
                ks.load(in, "senha1".toCharArray());
            }
            Certificate cert = ks.getCertificate("inter");
            PrivateKey chave = (PrivateKey) ks.getKey("inter", "senha1".toCharArray());
            CERT = Files.writeString(dir.resolve("teste-cert.pem"), pem("CERTIFICATE", cert.getEncoded()));
            CHAVE = Files.writeString(dir.resolve("teste-chave.pem"), pem("PRIVATE KEY", chave.getEncoded()));
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    private static String pem(String tipo, byte[] der) {
        return "-----BEGIN " + tipo + "-----\n" + Base64.getMimeEncoder(64, "\n".getBytes()).encodeToString(der)
                + "\n-----END " + tipo + "-----\n";
    }

    @DynamicPropertySource
    static void inter(DynamicPropertyRegistry r) {
        r.add("INTER_CRT", CERT::toString);
        r.add("INTER_KEY", CHAVE::toString);
        r.add("INTER_BASE_URL", () -> "https://127.0.0.1:1");
        r.add("INTER_CLIENT_ID", () -> "id");
        r.add("INTER_CLIENT_SECRET", () -> "segredo");
        r.add("INTER_CHAVE_PIX", () -> "chave");
        r.add("INTER_WEBHOOK_SEGREDO", () -> "segredo-webhook");
        r.add("JWT_SECRET", () -> "segredo-de-teste-com-mais-de-32-bytes-0123");
        r.add("DEV_KEY", () -> "dev");
        // Os jobs não devem chamar o provedor falso durante o teste.
        r.add("app.jobs.consulta-pagamento-intervalo-ms", () -> "3600000");
    }

    abstract static class Base {
        @LocalServerPort
        int porta;

        @Autowired
        ApplicationContext contexto;

        int status(String metodo, String caminho) throws IOException, InterruptedException {
            HttpRequest req = HttpRequest.newBuilder(URI.create("http://localhost:" + porta + caminho))
                    .method(metodo, "POST".equals(metodo) ? HttpRequest.BodyPublishers.ofString("[]")
                            : HttpRequest.BodyPublishers.noBody())
                    .header("Content-Type", "application/json")
                    .build();
            return HttpClient.newHttpClient().send(req, HttpResponse.BodyHandlers.discarding()).statusCode();
        }
    }

    @Nested
    @SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
    @ActiveProfiles("inter-prod")
    class InterProd extends Base {

        @Test
        void usaOProvedorExternoSemSimulacaoNemDocumentacao() throws Exception {
            assertThat(contexto.getBean(PixGateway.class)).isInstanceOf(InterPixGateway.class);
            assertThat(contexto.containsBean("devPagamentoController")).isFalse();
            assertThat(contexto.containsBean("consultaPagamentoJob")).isTrue();
            assertThat(contexto.containsBean("interWebhookController")).isTrue();
            assertThat(status("GET", "/v3/api-docs")).isEqualTo(404);
            assertThat(status("GET", "/swagger-ui.html")).isEqualTo(404);
            assertThat(status("POST", "/api/v1/webhooks/inter/pix/segredo-webhook")).isEqualTo(200);
            assertThat(status("GET", "/actuator/health")).isEqualTo(200);
        }
    }

    @Nested
    @SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
    @ActiveProfiles("inter-sandbox")
    class InterSandbox extends Base {

        @Test
        void temProvedorExternoSimulacaoWebhookJobEDocumentacao() throws Exception {
            assertThat(contexto.getBean(PixGateway.class)).isInstanceOf(InterPixGateway.class);
            assertThat(contexto.containsBean("devPagamentoController")).isTrue();
            assertThat(contexto.containsBean("consultaPagamentoJob")).isTrue();
            assertThat(status("GET", "/v3/api-docs")).isEqualTo(200);
            assertThat(status("POST", "/api/v1/webhooks/inter/pix/errado")).isEqualTo(404);
        }
    }

    @Nested
    @SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
    @ActiveProfiles("simulado")
    class Simulado extends Base {

        @Test
        void padraoSemWebhookNemJobDeConsulta() throws Exception {
            assertThat(contexto.getBean(PixGateway.class).provedor().name()).isEqualTo("SIMULADO");
            assertThat(contexto.containsBean("devPagamentoController")).isTrue();
            assertThat(contexto.containsBean("consultaPagamentoJob")).isFalse();
            assertThat(contexto.containsBean("interWebhookController")).isFalse();
            assertThat(status("GET", "/v3/api-docs")).isEqualTo(200);
        }
    }
}
