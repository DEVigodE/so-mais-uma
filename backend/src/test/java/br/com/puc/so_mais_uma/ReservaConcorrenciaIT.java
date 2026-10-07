package br.com.puc.so_mais_uma;

import static org.assertj.core.api.Assertions.assertThat;

import br.com.puc.so_mais_uma.entity.PerfilUsuario;
import br.com.puc.so_mais_uma.entity.Quadra;
import br.com.puc.so_mais_uma.entity.StatusReserva;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * RN08 pela API real: 10 clientes distintos disputam o mesmo par quadra/início ao mesmo tempo.
 * A exclusividade vem do índice único parcial {@code ux_reserva_slot_ativo}, não de lock.
 */
@ExtendWith(OutputCaptureExtension.class)
class ReservaConcorrenciaIT extends IntegracaoTestBase {

    private static final int CLIENTES = 10;
    private static final Pattern TOKEN = Pattern.compile("\"token\"\\s*:\\s*\"([^\"]+)\"");

    @LocalServerPort
    private int porta;

    @Autowired
    private JdbcTemplate jdbc;

    private final HttpClient http = HttpClient.newHttpClient();

    @Test
    void dezClientesDisputamOMesmoSlotEExatamenteUmVence(CapturedOutput log) throws Exception {
        Quadra quadra = novaQuadra(novoUsuario(PerfilUsuario.DONO));
        abrirTodosOsDias(quadra, 8, 22);
        Instant inicio = horaLocal(2, 20);
        String corpo = """
                {"quadraId": %d, "inicio": "%s"}""".formatted(quadra.getId(), inicio.atOffset(ZoneOffset.ofHours(-3)));

        List<String> tokens = new ArrayList<>();
        for (int i = 0; i < CLIENTES; i++) {
            tokens.add(registrarCliente());
        }

        CountDownLatch largada = new CountDownLatch(1);
        ExecutorService pool = Executors.newFixedThreadPool(CLIENTES);
        List<Future<HttpResponse<String>>> futuros = new ArrayList<>();
        try {
            for (String token : tokens) {
                futuros.add(pool.submit(() -> {
                    largada.await();
                    return http.send(post("/api/v1/reservas", corpo, token), HttpResponse.BodyHandlers.ofString());
                }));
            }
            largada.countDown();

            int criadas = 0;
            int conflitos = 0;
            for (Future<HttpResponse<String>> f : futuros) {
                HttpResponse<String> resposta = f.get();
                if (resposta.statusCode() == 201) {
                    criadas++;
                } else if (resposta.statusCode() == 409) {
                    assertThat(resposta.body()).contains("\"codigo\":\"HORARIO_INDISPONIVEL\"");
                    conflitos++;
                } else {
                    throw new AssertionError("Status inesperado " + resposta.statusCode() + ": " + resposta.body());
                }
            }
            assertThat(criadas).isEqualTo(1);
            assertThat(conflitos).isEqualTo(CLIENTES - 1);
        } finally {
            pool.shutdownNow();
        }

        Integer ativas = jdbc.queryForObject("""
                SELECT count(*) FROM reserva WHERE quadra_id = ? AND inicio = ? AND status IN (?, ?)""",
                Integer.class, quadra.getId(), java.sql.Timestamp.from(inicio),
                StatusReserva.PENDENTE_PAGAMENTO.name(), StatusReserva.CONFIRMADA.name());
        assertThat(ativas).isEqualTo(1);

        Integer cobrancas = jdbc.queryForObject("""
                SELECT count(*) FROM pagamento p JOIN reserva r ON r.id = p.reserva_id
                WHERE r.quadra_id = ? AND r.inicio = ?""", Integer.class, quadra.getId(),
                java.sql.Timestamp.from(inicio));
        assertThat(cobrancas).isEqualTo(1);

        assertThat(log.getOut()).doesNotContain("Erro não tratado");
    }

    private String registrarCliente() throws Exception {
        String corpo = """
                {"nome":"Cliente","email":"c-%s@teste.com","senha":"Senha123","perfil":"CLIENTE"}"""
                .formatted(UUID.randomUUID());
        HttpResponse<String> resposta = http.send(post("/api/v1/auth/registrar", corpo, null),
                HttpResponse.BodyHandlers.ofString());
        assertThat(resposta.statusCode()).isEqualTo(201);
        Matcher m = TOKEN.matcher(resposta.body());
        assertThat(m.find()).isTrue();
        return m.group(1);
    }

    private HttpRequest post(String caminho, String corpo, String token) {
        HttpRequest.Builder b = HttpRequest.newBuilder(URI.create("http://localhost:" + porta + caminho))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(corpo));
        if (token != null) {
            b.header("Authorization", "Bearer " + token);
        }
        return b.build();
    }
}
