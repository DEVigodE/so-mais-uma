package br.com.puc.so_mais_uma.service;

import static org.assertj.core.api.Assertions.assertThat;

import br.com.puc.so_mais_uma.IntegracaoTestBase;
import br.com.puc.so_mais_uma.dto.ReservaDtos.CriarReservaRequest;
import br.com.puc.so_mais_uma.entity.Pagamento;
import br.com.puc.so_mais_uma.entity.PerfilUsuario;
import br.com.puc.so_mais_uma.entity.Quadra;
import br.com.puc.so_mais_uma.entity.StatusPagamento;
import br.com.puc.so_mais_uma.entity.StatusReserva;
import br.com.puc.so_mais_uma.entity.Usuario;
import br.com.puc.so_mais_uma.repository.PagamentoRepository;
import br.com.puc.so_mais_uma.service.PagamentoService.ResultadoConfirmacao;
import br.com.puc.so_mais_uma.service.ReservaService.ReservaComPagamento;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.jdbc.core.JdbcTemplate;

/** Ponto único de confirmação (design.md D5/D6) contra o PostgreSQL real. */
@ExtendWith(OutputCaptureExtension.class)
class PagamentoServiceTest extends IntegracaoTestBase {

    private static final BigDecimal VALOR = new BigDecimal("80.00");

    @Autowired
    private PagamentoService pagamentoService;

    @Autowired
    private ReservaFacade facade;

    @Autowired
    private ReservaService reservaService;

    @Autowired
    private PagamentoRepository pagamentoRepository;

    @Autowired
    private JdbcTemplate jdbc;

    private Quadra quadra;
    private Instant slot;

    @BeforeEach
    void setUp() {
        quadra = novaQuadra(novoUsuario(PerfilUsuario.DONO));
        abrirTodosOsDias(quadra, 8, 22);
        slot = horaLocal(3, 18);
    }

    private ReservaComPagamento reservar(Usuario cliente) {
        return facade.criar(autenticado(cliente),
                new CriarReservaRequest(quadra.getId(), slot.atOffset(ZoneOffset.ofHours(-3)), null));
    }

    private static String e2e() {
        return "E" + UUID.randomUUID().toString().replace("-", "").substring(0, 31);
    }

    private StatusReserva statusReserva(Long id) {
        return reservaRepository.lerStatus(id).orElseThrow();
    }

    private StatusPagamento statusPagamento(String txid) {
        return pagamentoRepository.lerStatus(txid).orElseThrow();
    }

    /** Força o vencimento e roda o ciclo de expiração. */
    private void expirar(Long reservaId) {
        jdbc.update("UPDATE reserva SET expira_em = now() - interval '1 minute' WHERE id = ?", reservaId);
        jdbc.update("UPDATE pagamento SET expira_em = now() - interval '1 minute' WHERE reserva_id = ?", reservaId);
        reservaService.expirarVencidas();
    }

    @Test
    void confirmacaoDuplaAfetaUmaVezESegundaNaoFazNada() {
        ReservaComPagamento r = reservar(novoUsuario(PerfilUsuario.CLIENTE));
        String txid = r.pagamento().getTxid();
        String fimAFim = e2e();

        assertThat(pagamentoService.confirmar(txid, fimAFim, VALOR, Instant.now()))
                .isEqualTo(ResultadoConfirmacao.CONFIRMADO);
        assertThat(pagamentoService.confirmar(txid, fimAFim, VALOR, Instant.now()))
                .isEqualTo(ResultadoConfirmacao.JA_PROCESSADO);

        assertThat(statusPagamento(txid)).isEqualTo(StatusPagamento.PAGO);
        assertThat(statusReserva(r.reserva().getId())).isEqualTo(StatusReserva.CONFIRMADA);
    }

    @Test
    void jobEWebhookSimultaneosConfirmamExatamenteUmaVez() throws Exception {
        ReservaComPagamento r = reservar(novoUsuario(PerfilUsuario.CLIENTE));
        String txid = r.pagamento().getTxid();
        String fimAFim = e2e();
        CountDownLatch largada = new CountDownLatch(1);
        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            List<Future<ResultadoConfirmacao>> resultados = List.of(
                    pool.submit(() -> { largada.await(); return pagamentoService.confirmar(txid, fimAFim, VALOR, Instant.now()); }),
                    pool.submit(() -> { largada.await(); return pagamentoService.confirmar(txid, fimAFim, VALOR, Instant.now()); }));
            largada.countDown();
            List<ResultadoConfirmacao> obtidos = List.of(resultados.get(0).get(), resultados.get(1).get());

            assertThat(obtidos).containsExactlyInAnyOrder(ResultadoConfirmacao.CONFIRMADO,
                    ResultadoConfirmacao.JA_PROCESSADO);
        } finally {
            pool.shutdownNow();
        }
        assertThat(statusReserva(r.reserva().getId())).isEqualTo(StatusReserva.CONFIRMADA);
    }

    @Test
    void valorDivergenteNaoConfirmaEVaiParaOLog(CapturedOutput log) {
        ReservaComPagamento r = reservar(novoUsuario(PerfilUsuario.CLIENTE));
        String txid = r.pagamento().getTxid();

        assertThat(pagamentoService.confirmar(txid, e2e(), new BigDecimal("79.99"), Instant.now()))
                .isEqualTo(ResultadoConfirmacao.VALOR_DIVERGENTE);

        assertThat(statusPagamento(txid)).isEqualTo(StatusPagamento.PENDENTE);
        assertThat(statusReserva(r.reserva().getId())).isEqualTo(StatusReserva.PENDENTE_PAGAMENTO);
        assertThat(log.getOut()).contains("Valor divergente no txid " + txid);
    }

    @Test
    void txidDesconhecidoETratadoSemErro() {
        assertThat(pagamentoService.confirmar("naoexiste00000000000000000000000", e2e(), VALOR, Instant.now()))
                .isEqualTo(ResultadoConfirmacao.DESCONHECIDO);
    }

    @Test
    void identificadorFimAFimRepetidoEmOutraCobrancaETratadoComoJaProcessado() {
        String fimAFim = e2e();
        ReservaComPagamento a = reservar(novoUsuario(PerfilUsuario.CLIENTE));
        pagamentoService.confirmar(a.pagamento().getTxid(), fimAFim, VALOR, Instant.now());
        slot = horaLocal(3, 20);
        ReservaComPagamento b = reservar(novoUsuario(PerfilUsuario.CLIENTE));

        assertThat(pagamentoService.confirmar(b.pagamento().getTxid(), fimAFim, VALOR, Instant.now()))
                .isEqualTo(ResultadoConfirmacao.JA_PROCESSADO);

        assertThat(statusPagamento(b.pagamento().getTxid())).isEqualTo(StatusPagamento.PENDENTE);
        assertThat(statusReserva(b.reserva().getId())).isEqualTo(StatusReserva.PENDENTE_PAGAMENTO);
    }

    @Test
    void pagamentoTardioComSlotLivreReconfirmaAReserva(CapturedOutput log) {
        ReservaComPagamento r = reservar(novoUsuario(PerfilUsuario.CLIENTE));
        expirar(r.reserva().getId());
        assertThat(statusReserva(r.reserva().getId())).isEqualTo(StatusReserva.EXPIRADA);
        assertThat(statusPagamento(r.pagamento().getTxid())).isEqualTo(StatusPagamento.EXPIRADO);

        assertThat(pagamentoService.confirmar(r.pagamento().getTxid(), e2e(), VALOR, Instant.now()))
                .isEqualTo(ResultadoConfirmacao.TARDIO_RECONFIRMADO);

        assertThat(statusReserva(r.reserva().getId())).isEqualTo(StatusReserva.CONFIRMADA);
        assertThat(statusPagamento(r.pagamento().getTxid())).isEqualTo(StatusPagamento.PAGO);
        assertThat(log.getOut()).contains("reconfirmada");
    }

    @Test
    void pagamentoTardioComSlotTomadoPedeEstornoManualEPreservaOOutroCliente(CapturedOutput log) {
        ReservaComPagamento a = reservar(novoUsuario(PerfilUsuario.CLIENTE));
        expirar(a.reserva().getId());
        ReservaComPagamento b = reservar(novoUsuario(PerfilUsuario.CLIENTE)); // retoma o slot liberado
        String txidA = a.pagamento().getTxid();

        assertThat(pagamentoService.confirmar(txidA, e2e(), VALOR, Instant.now()))
                .isEqualTo(ResultadoConfirmacao.TARDIO_ESTORNO_MANUAL);

        assertThat(statusReserva(a.reserva().getId())).isEqualTo(StatusReserva.EXPIRADA);
        assertThat(statusPagamento(txidA)).isEqualTo(StatusPagamento.PAGO);
        assertThat(statusReserva(b.reserva().getId())).isEqualTo(StatusReserva.PENDENTE_PAGAMENTO);
        assertThat(log.getOut()).contains("ESTORNO MANUAL NECESSÁRIO: pagamento tardio txid=" + txidA)
                .contains("reserva=" + a.reserva().getId()).contains("valor=80.00");
    }

    @Test
    void pagamentoTardioParaReservaCanceladaMarcaPagoEPedeEstorno(CapturedOutput log) {
        Usuario cliente = novoUsuario(PerfilUsuario.CLIENTE);
        ReservaComPagamento r = reservar(cliente);
        facade.cancelar(r.reserva().getId(), autenticado(cliente), null);
        assertThat(statusPagamento(r.pagamento().getTxid())).isEqualTo(StatusPagamento.CANCELADO);

        assertThat(pagamentoService.confirmar(r.pagamento().getTxid(), e2e(), VALOR, Instant.now()))
                .isEqualTo(ResultadoConfirmacao.TARDIO_ESTORNO_MANUAL);

        assertThat(statusReserva(r.reserva().getId())).isEqualTo(StatusReserva.CANCELADA);
        assertThat(statusPagamento(r.pagamento().getTxid())).isEqualTo(StatusPagamento.PAGO);
        assertThat(log.getOut()).contains("ESTORNO MANUAL NECESSÁRIO");
    }

    @Test
    void expiracaoLiberaOSlotParaOutroCliente() {
        ReservaComPagamento a = reservar(novoUsuario(PerfilUsuario.CLIENTE));
        expirar(a.reserva().getId());

        ReservaComPagamento b = reservar(novoUsuario(PerfilUsuario.CLIENTE));

        assertThat(b.reserva().getStatus()).isEqualTo(StatusReserva.PENDENTE_PAGAMENTO);
        Pagamento pagamentoB = b.pagamento();
        assertThat(pagamentoB.getExpiraEm()).isEqualTo(b.reserva().getExpiraEm());
        assertThat(pagamentoB.getTxid()).hasSize(32).matches("[a-f0-9]{32}");
    }
}
