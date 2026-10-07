package br.com.puc.so_mais_uma.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.willThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import br.com.puc.so_mais_uma.dto.ReservaDtos.CriarReservaRequest;
import br.com.puc.so_mais_uma.entity.HorarioFuncionamento;
import br.com.puc.so_mais_uma.entity.PerfilUsuario;
import br.com.puc.so_mais_uma.entity.Quadra;
import br.com.puc.so_mais_uma.entity.Reserva;
import br.com.puc.so_mais_uma.entity.StatusReserva;
import br.com.puc.so_mais_uma.entity.Usuario;
import br.com.puc.so_mais_uma.exception.ApiException;
import br.com.puc.so_mais_uma.exception.CodigoErro;
import br.com.puc.so_mais_uma.exception.RegraNegocioException;
import br.com.puc.so_mais_uma.exception.SubcodigoErro;
import br.com.puc.so_mais_uma.exception.ValidacaoException;
import br.com.puc.so_mais_uma.repository.HorarioFuncionamentoRepository;
import br.com.puc.so_mais_uma.repository.PagamentoRepository;
import br.com.puc.so_mais_uma.repository.ReservaRepository;
import br.com.puc.so_mais_uma.repository.UsuarioRepository;
import br.com.puc.so_mais_uma.security.UsuarioAutenticado;
import br.com.puc.so_mais_uma.support.Fixtures;
import br.com.puc.so_mais_uma.support.RelogioAjustavel;
import java.math.BigDecimal;
import java.sql.SQLException;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.Optional;
import org.hibernate.exception.ConstraintViolationException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;

class ReservaServiceTest {

    private static final ZoneId SP = ZoneId.of("America/Sao_Paulo");
    /** Sábado, 10/10/2026, 14:30 em São Paulo. */
    private static final Instant AGORA = OffsetDateTime.parse("2026-10-10T14:30:00-03:00").toInstant();
    private static final OffsetDateTime AMANHA_19H = OffsetDateTime.parse("2026-10-11T19:00:00-03:00");

    private final RelogioAjustavel relogio = new RelogioAjustavel(AGORA);
    private final ReservaRepository reservas = mock(ReservaRepository.class);
    private final PagamentoRepository pagamentos = mock(PagamentoRepository.class);
    private final UsuarioRepository usuarios = mock(UsuarioRepository.class);
    private final QuadraService quadraService = mock(QuadraService.class);
    private final HorarioFuncionamentoRepository horarios = mock(HorarioFuncionamentoRepository.class);
    private final ReservaValidador validador = new ReservaValidador(horarios, relogio, SP, Fixtures.props());
    private final ReservaService service = new ReservaService(reservas, pagamentos, usuarios, quadraService,
            validador, relogio, SP, Fixtures.props());

    private final Usuario cliente = Fixtures.usuario(2, PerfilUsuario.CLIENTE);
    private final Usuario dono = Fixtures.usuario(9, PerfilUsuario.DONO);
    private Quadra quadra;

    @BeforeEach
    void setUp() {
        quadra = new Quadra();
        quadra.setId(1L);
        quadra.setDono(dono);
        quadra.setPrecoHora(new BigDecimal("80.00"));
        quadra.setAtiva(true);
        given(quadraService.buscar(1L)).willReturn(quadra);
        given(usuarios.getReferenceById(2L)).willReturn(cliente);
        given(horarios.findByQuadraIdAndDiaSemana(anyLong(), anyInt())).willAnswer(inv -> {
            HorarioFuncionamento h = new HorarioFuncionamento();
            h.setQuadra(quadra);
            h.setDiaSemana(inv.getArgument(1));
            h.setHoraAbertura(LocalTime.of(8, 0));
            h.setHoraFechamento(LocalTime.of(22, 0));
            return Optional.of(h);
        });
        given(reservas.findFirstByClienteIdAndStatus(anyLong(), any())).willReturn(Optional.empty());
        given(reservas.saveAndFlush(any())).willAnswer(inv -> inv.getArgument(0));
    }

    private Reserva criar(OffsetDateTime inicio) {
        return service.criarPendente(2L, new CriarReservaRequest(1L, inicio, null));
    }

    @Test
    void reservaNasceePendenteComFimValorEExpiracao() {
        Reserva r = criar(AMANHA_19H);

        assertThat(r.getStatus()).isEqualTo(StatusReserva.PENDENTE_PAGAMENTO);
        assertThat(r.getFim()).isEqualTo(r.getInicio().plus(Duration.ofHours(1)));
        assertThat(r.getValor()).isEqualByComparingTo("80.00");
        assertThat(r.getExpiraEm()).isEqualTo(AGORA.plus(Duration.ofMinutes(15)));
    }

    @Test
    void inicioForaDaHoraCheiaE400NoCampoInicio() {
        assertThatThrownBy(() -> criar(AMANHA_19H.withMinute(30)))
                .isInstanceOfSatisfying(ValidacaoException.class, e -> assertThat(e.getCampo()).isEqualTo("inicio"));
    }

    @Test
    void inicioNoPassadoE400() {
        assertThatThrownBy(() -> criar(OffsetDateTime.parse("2026-10-10T14:00:00-03:00")))
                .isInstanceOf(ValidacaoException.class);
    }

    @Test
    void inicioForaDaJanelaE422() {
        assertThatThrownBy(() -> criar(AMANHA_19H.plusDays(14)))
                .isInstanceOfSatisfying(RegraNegocioException.class,
                        e -> assertThat(e.getSubcodigo()).isEqualTo(SubcodigoErro.DATA_FORA_DA_JANELA));
    }

    @Test
    void inicioForaDoFuncionamentoE422() {
        assertThatThrownBy(() -> criar(AMANHA_19H.withHour(7)))
                .isInstanceOfSatisfying(RegraNegocioException.class,
                        e -> assertThat(e.getSubcodigo()).isEqualTo(SubcodigoErro.FORA_DO_FUNCIONAMENTO));
        assertThatThrownBy(() -> criar(AMANHA_19H.withHour(22)))
                .isInstanceOfSatisfying(RegraNegocioException.class,
                        e -> assertThat(e.getSubcodigo()).isEqualTo(SubcodigoErro.FORA_DO_FUNCIONAMENTO));
    }

    @Test
    void diaSemFaixaE422ForaDoFuncionamento() {
        given(horarios.findByQuadraIdAndDiaSemana(anyLong(), anyInt())).willReturn(Optional.empty());

        assertThatThrownBy(() -> criar(AMANHA_19H))
                .isInstanceOfSatisfying(RegraNegocioException.class,
                        e -> assertThat(e.getSubcodigo()).isEqualTo(SubcodigoErro.FORA_DO_FUNCIONAMENTO));
    }

    @Test
    void quadraInativaE404() {
        quadra.setAtiva(false);

        assertThatThrownBy(() -> criar(AMANHA_19H)).isInstanceOfSatisfying(ApiException.class,
                e -> assertThat(e.getCodigo()).isEqualTo(CodigoErro.NAO_ENCONTRADO));
    }

    @Test
    void reservaPendenteExistenteE422ComReservaId() {
        Reserva pendente = new Reserva();
        pendente.setId(42L);
        given(reservas.findFirstByClienteIdAndStatus(2L, StatusReserva.PENDENTE_PAGAMENTO))
                .willReturn(Optional.of(pendente));

        assertThatThrownBy(() -> criar(AMANHA_19H)).isInstanceOfSatisfying(RegraNegocioException.class, e -> {
            assertThat(e.getSubcodigo()).isEqualTo(SubcodigoErro.RESERVA_PENDENTE_EXISTENTE);
            assertThat(e.getExtensoes()).containsEntry("reservaId", 42L);
        });
        verify(reservas, never()).saveAndFlush(any());
    }

    @Test
    void violacaoDoSlotViraHorarioIndisponivelEOutraViolacaoSobe() {
        willThrow(violacao("ux_reserva_slot_ativo")).given(reservas).saveAndFlush(any());
        assertThatThrownBy(() -> criar(AMANHA_19H)).isInstanceOfSatisfying(ApiException.class,
                e -> assertThat(e.getCodigo()).isEqualTo(CodigoErro.HORARIO_INDISPONIVEL));

        willThrow(violacao("ck_reserva_duracao")).given(reservas).saveAndFlush(any());
        assertThatThrownBy(() -> criar(AMANHA_19H)).isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void alteracaoCondicionalQueAfetaZeroLinhasE422TransicaoInvalida() {
        Reserva r = new Reserva();
        r.setId(5L);
        r.setQuadra(quadra);
        r.setCliente(cliente);
        r.setInicio(AMANHA_19H.toInstant());
        r.setStatus(StatusReserva.PENDENTE_PAGAMENTO);
        given(reservas.findDetalhadaById(5L)).willReturn(Optional.of(r));
        // Outro fluxo (confirmação) venceu a corrida: o UPDATE não encontra mais o status esperado.
        given(reservas.cancelar(eq(5L), eq(StatusReserva.PENDENTE_PAGAMENTO), any(), any(), any())).willReturn(0);

        UsuarioAutenticado autenticado = new UsuarioAutenticado(2L, PerfilUsuario.CLIENTE, "Cli");
        assertThatThrownBy(() -> service.cancelar(5L, autenticado, null))
                .isInstanceOfSatisfying(RegraNegocioException.class,
                        e -> assertThat(e.getSubcodigo()).isEqualTo(SubcodigoErro.TRANSICAO_INVALIDA));
        verify(pagamentos, never()).cancelarDaReserva(anyLong(), any());
    }

    private static DataIntegrityViolationException violacao(String constraint) {
        return new DataIntegrityViolationException("violação",
                new ConstraintViolationException("violação", new SQLException("x"), constraint));
    }
}
