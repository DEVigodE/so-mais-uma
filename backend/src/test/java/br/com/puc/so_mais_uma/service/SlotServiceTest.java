package br.com.puc.so_mais_uma.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.mock;

import br.com.puc.so_mais_uma.dto.ReservaDtos.SlotResponse;
import br.com.puc.so_mais_uma.entity.HorarioFuncionamento;
import br.com.puc.so_mais_uma.entity.PerfilUsuario;
import br.com.puc.so_mais_uma.entity.Quadra;
import br.com.puc.so_mais_uma.entity.StatusSlot;
import br.com.puc.so_mais_uma.exception.RegraNegocioException;
import br.com.puc.so_mais_uma.exception.SubcodigoErro;
import br.com.puc.so_mais_uma.exception.ValidacaoException;
import br.com.puc.so_mais_uma.repository.HorarioFuncionamentoRepository;
import br.com.puc.so_mais_uma.repository.ReservaRepository;
import br.com.puc.so_mais_uma.security.UsuarioAutenticado;
import br.com.puc.so_mais_uma.support.Fixtures;
import br.com.puc.so_mais_uma.support.RelogioAjustavel;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class SlotServiceTest {

    private static final ZoneId SP = ZoneId.of("America/Sao_Paulo");
    /** Sábado, 10/10/2026, 14:30 em São Paulo. */
    private static final Instant AGORA = OffsetDateTime.parse("2026-10-10T14:30:00-03:00").toInstant();
    private static final LocalDate HOJE = LocalDate.of(2026, 10, 10);
    private static final int SABADO = 6;

    private final RelogioAjustavel relogio = new RelogioAjustavel(AGORA);
    private final QuadraService quadraService = mock(QuadraService.class);
    private final HorarioFuncionamentoRepository horarios = mock(HorarioFuncionamentoRepository.class);
    private final ReservaRepository reservas = mock(ReservaRepository.class);
    private final ReservaValidador validador = new ReservaValidador(horarios, relogio, SP, Fixtures.props());
    private final SlotService service = new SlotService(quadraService, horarios, reservas, validador, relogio, SP);
    private final UsuarioAutenticado cliente = new UsuarioAutenticado(2L, PerfilUsuario.CLIENTE, "Cli");

    private Quadra quadra;

    @BeforeEach
    void setUp() {
        quadra = new Quadra();
        quadra.setId(1L);
        quadra.setDono(Fixtures.usuario(9, PerfilUsuario.DONO));
        quadra.setPrecoHora(new BigDecimal("80.00"));
        quadra.setAtiva(true);
        given(quadraService.buscarVisivel(eq(1L), any())).willReturn(quadra);
        given(horarios.findByQuadraIdAndDiaSemana(anyLong(), anyInt())).willReturn(Optional.empty());
        given(reservas.buscarIniciosOcupados(anyLong(), any(), any(), any())).willReturn(List.of());
    }

    private void abrir(int dia, int abertura, int fechamento) {
        HorarioFuncionamento h = new HorarioFuncionamento();
        h.setQuadra(quadra);
        h.setDiaSemana(dia);
        h.setHoraAbertura(LocalTime.of(abertura, 0));
        h.setHoraFechamento(LocalTime.of(fechamento, 0));
        given(horarios.findByQuadraIdAndDiaSemana(1L, dia)).willReturn(Optional.of(h));
    }

    private static Instant local(LocalDate data, int hora) {
        return data.atTime(hora, 0).atZone(SP).toInstant();
    }

    @Test
    void quadraAbertaDas8As22TemQuatorzeSlotsComOPrecoAtual() {
        LocalDate amanha = HOJE.plusDays(1); // domingo
        abrir(7, 8, 22);

        List<SlotResponse> grade = service.grade(1L, amanha, cliente);

        assertThat(grade).hasSize(14);
        assertThat(grade.getFirst().inicio().toInstant()).isEqualTo(local(amanha, 8));
        assertThat(grade.getLast().inicio().toInstant()).isEqualTo(local(amanha, 21));
        assertThat(grade.getLast().fim().toInstant()).isEqualTo(local(amanha, 22));
        assertThat(grade).allSatisfy(s -> {
            assertThat(s.valor()).isEqualByComparingTo("80.00");
            assertThat(s.status()).isEqualTo(StatusSlot.LIVRE);
        });
    }

    @Test
    void quatroStatusNaGradeDeHoje() {
        abrir(SABADO, 8, 22);
        given(reservas.buscarIniciosOcupados(anyLong(), any(), any(), any()))
                .willReturn(List.of(local(HOJE, 19)));

        List<SlotResponse> grade = service.grade(1L, HOJE, cliente);

        assertThat(grade).filteredOn(s -> s.inicio().toInstant().isBefore(local(HOJE, 15)))
                .hasSize(7) // 08..14
                .allSatisfy(s -> assertThat(s.status()).isEqualTo(StatusSlot.PASSADO));
        assertThat(status(grade, 15)).isEqualTo(StatusSlot.LIVRE);
        assertThat(status(grade, 19)).isEqualTo(StatusSlot.OCUPADO);
    }

    @Test
    void diaSemFaixaVemInteiramenteFechado() {
        List<SlotResponse> grade = service.grade(1L, HOJE.plusDays(2), cliente);

        assertThat(grade).hasSize(24).allSatisfy(s -> assertThat(s.status()).isEqualTo(StatusSlot.FECHADO));
    }

    @Test
    void gradeSempreNoFusoDeReferencia() {
        abrir(7, 8, 22);

        SlotResponse primeiro = service.grade(1L, HOJE.plusDays(1), cliente).getFirst();

        assertThat(primeiro.inicio().atZoneSameInstant(SP).toLocalTime()).isEqualTo(LocalTime.of(8, 0));
        assertThat(primeiro.inicio().toInstant()).isEqualTo(Instant.parse("2026-10-11T11:00:00Z"));
    }

    @Test
    void janelaAceitaHojeMais14ERecusaHojeMais15() {
        assertThat(service.grade(1L, HOJE.plusDays(14), cliente)).isNotEmpty();
        assertThatThrownBy(() -> service.grade(1L, HOJE.plusDays(15), cliente))
                .isInstanceOfSatisfying(RegraNegocioException.class,
                        e -> assertThat(e.getSubcodigo()).isEqualTo(SubcodigoErro.DATA_FORA_DA_JANELA));
        assertThatThrownBy(() -> service.grade(1L, HOJE.minusDays(1), cliente))
                .isInstanceOf(ValidacaoException.class);
    }

    @Test
    void instanteEnviadoEmOutroOffsetCaiNoMesmoSlot() {
        abrir(7, 8, 22);
        Quadra q = quadra;

        Instant emUtc = validador.validarInicio(q, OffsetDateTime.parse("2026-10-11T22:00:00Z"));
        Instant emSp = validador.validarInicio(q, OffsetDateTime.parse("2026-10-11T19:00:00-03:00"));

        assertThat(emUtc).isEqualTo(emSp);
    }

    private static StatusSlot status(List<SlotResponse> grade, int hora) {
        return grade.stream()
                .filter(s -> s.inicio().atZoneSameInstant(SP).getHour() == hora)
                .findFirst().orElseThrow().status();
    }
}
