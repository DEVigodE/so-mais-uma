package br.com.puc.so_mais_uma.integracao.cep;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import br.com.puc.so_mais_uma.exception.IntegracaoExternaException;
import br.com.puc.so_mais_uma.integracao.cep.CepClient.EnderecoCep;
import br.com.puc.so_mais_uma.integracao.cep.CepClient.Fonte;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.http.HttpClient;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

/** Fonte primária, fallback e falhas com servidores HTTP locais simulando BrasilAPI e ViaCEP. */
class CepClientTest {

    private static final String BRASILAPI_OK = """
            {"cep":"01001000","state":"SP","city":"São Paulo","neighborhood":"Sé","street":"Praça da Sé",
             "service":"open-cep","location":{"type":"Point","coordinates":{"longitude":"-46.6339","latitude":"-23.5505"}}}""";
    private static final String BRASILAPI_SEM_COORD = """
            {"cep":"01001000","state":"SP","city":"São Paulo","neighborhood":"Sé","street":"Praça da Sé",
             "location":{"type":"Point","coordinates":{}}}""";
    private static final String VIACEP_OK = """
            {"cep":"01001-000","logradouro":"Praça da Sé","bairro":"Sé","localidade":"São Paulo","uf":"SP"}""";

    private final Servidor primaria = new Servidor();
    private final Servidor secundaria = new Servidor();

    @AfterEach
    void parar() {
        primaria.parar();
        secundaria.parar();
    }

    private CepClient cliente() {
        HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofMillis(500)).build();
        JdkClientHttpRequestFactory fabrica = new JdkClientHttpRequestFactory(http);
        fabrica.setReadTimeout(Duration.ofMillis(500));
        return new CepClient(
                RestClient.builder().requestFactory(fabrica).baseUrl(primaria.url()).build(),
                RestClient.builder().requestFactory(fabrica).baseUrl(secundaria.url()).build());
    }

    @Test
    void sucessoNaFontePrimariaComCoordenadas() {
        primaria.responder(200, BRASILAPI_OK, 0);
        secundaria.responder(200, VIACEP_OK, 0);

        EnderecoCep e = cliente().consultar("01001000").orElseThrow();

        assertThat(e.fonte()).isEqualTo(Fonte.BRASILAPI);
        assertThat(e.cidade()).isEqualTo("São Paulo");
        assertThat(e.uf()).isEqualTo("SP");
        assertThat(e.latitude()).isEqualTo(-23.5505);
        assertThat(e.longitude()).isEqualTo(-46.6339);
        assertThat(secundaria.chamadas()).isZero();
    }

    @Test
    void fallbackParaASecundariaQuandoAPrimariaFalha() {
        primaria.responder(500, "{}", 0);
        secundaria.responder(200, VIACEP_OK, 0);

        EnderecoCep e = cliente().consultar("01001000").orElseThrow();

        assertThat(e.fonte()).isEqualTo(Fonte.VIACEP);
        assertThat(e.logradouro()).isEqualTo("Praça da Sé");
        assertThat(e.latitude()).isNull();
        assertThat(e.longitude()).isNull();
    }

    @Test
    void primariaLentaAcionaOFallback() {
        primaria.responder(200, BRASILAPI_OK, 2_000);
        secundaria.responder(200, VIACEP_OK, 0);

        long inicio = System.nanoTime();
        EnderecoCep e = cliente().consultar("01001000").orElseThrow();

        assertThat(e.fonte()).isEqualTo(Fonte.VIACEP);
        assertThat(Duration.ofNanos(System.nanoTime() - inicio)).isLessThan(Duration.ofMillis(1_800));
    }

    @Test
    void respostaSemCoordenadasDevolveEnderecoComLatitudeELongitudeVazias() {
        primaria.responder(200, BRASILAPI_SEM_COORD, 0);

        EnderecoCep e = cliente().consultar("01001000").orElseThrow();

        assertThat(e.fonte()).isEqualTo(Fonte.BRASILAPI);
        assertThat(e.logradouro()).isEqualTo("Praça da Sé");
        assertThat(e.latitude()).isNull();
        assertThat(e.longitude()).isNull();
    }

    @Test
    void cepInexistenteNasDuasFontesVoltaVazio() {
        primaria.responder(404, "{\"message\":\"not found\"}", 0);
        secundaria.responder(200, "{\"erro\": \"true\"}", 0);

        assertThat(cliente().consultar("99999999")).isEmpty();
    }

    @Test
    void falhaDasDuasFontesLancaErroDeIntegracao() {
        primaria.responder(503, "{}", 0);
        secundaria.responder(500, "{}", 0);

        assertThatThrownBy(() -> cliente().consultar("01001000")).isInstanceOf(IntegracaoExternaException.class);
    }

    /** Servidor HTTP mínimo que responde sempre o mesmo status e corpo. */
    private static final class Servidor {
        private HttpServer server;
        private final AtomicInteger chamadas = new AtomicInteger();

        void responder(int status, String corpo, long atrasoMs) {
            try {
                server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
            } catch (IOException e) {
                throw new IllegalStateException(e);
            }
            server.createContext("/", troca -> {
                chamadas.incrementAndGet();
                try {
                    Thread.sleep(atrasoMs);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
                byte[] bytes = corpo.getBytes(StandardCharsets.UTF_8);
                troca.getResponseHeaders().add("Content-Type", "application/json; charset=utf-8");
                try {
                    troca.sendResponseHeaders(status, bytes.length);
                    troca.getResponseBody().write(bytes);
                } catch (IOException ignorada) {
                    // cliente desistiu por tempo limite
                } finally {
                    troca.close();
                }
            });
            server.setExecutor(java.util.concurrent.Executors.newCachedThreadPool());
            server.start();
        }

        String url() {
            if (server == null) {
                responder(500, "{}", 0);
            }
            return "http://127.0.0.1:" + server.getAddress().getPort();
        }

        int chamadas() {
            return chamadas.get();
        }

        void parar() {
            if (server != null) {
                server.stop(0);
            }
        }
    }
}
