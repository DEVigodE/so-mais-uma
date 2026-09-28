package br.com.puc.so_mais_uma.service;

import br.com.puc.so_mais_uma.dto.QuadraDtos.AtualizarHorarioRequest;
import br.com.puc.so_mais_uma.dto.QuadraDtos.HorarioFuncionamentoRequest;
import br.com.puc.so_mais_uma.entity.HorarioFuncionamento;
import br.com.puc.so_mais_uma.entity.Quadra;
import br.com.puc.so_mais_uma.entity.Reserva;
import br.com.puc.so_mais_uma.entity.StatusReserva;
import br.com.puc.so_mais_uma.exception.CodigoErro;
import br.com.puc.so_mais_uma.exception.Excecoes;
import br.com.puc.so_mais_uma.exception.ViolacaoDeIntegridade;
import br.com.puc.so_mais_uma.repository.HorarioFuncionamentoRepository;
import br.com.puc.so_mais_uma.repository.ReservaRepository;
import br.com.puc.so_mais_uma.security.UsuarioAutenticado;
import java.time.Clock;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.List;
import java.util.function.Predicate;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * CRUD das faixas de funcionamento (RF11, RN19): no máximo uma por dia da semana; alteração ou
 * remoção que deixaria reserva ativa futura fora do funcionamento é recusada (RN16).
 */
@Service
public class HorarioFuncionamentoService {

    private final HorarioFuncionamentoRepository horarios;
    private final ReservaRepository reservas;
    private final QuadraService quadraService;
    private final Clock relogio;
    private final ZoneId fuso;

    public HorarioFuncionamentoService(HorarioFuncionamentoRepository horarios, ReservaRepository reservas,
            QuadraService quadraService, Clock relogio, ZoneId fusoReferencia) {
        this.horarios = horarios;
        this.reservas = reservas;
        this.quadraService = quadraService;
        this.relogio = relogio;
        this.fuso = fusoReferencia;
    }

    @Transactional(readOnly = true)
    public List<HorarioFuncionamento> listar(Long quadraId, UsuarioAutenticado usuario) {
        quadraService.buscarVisivel(quadraId, usuario);
        return horarios.findByQuadraIdOrderByDiaSemanaAsc(quadraId);
    }

    /** Faixas de uma quadra já carregada, sem nova checagem de visibilidade. */
    @Transactional(readOnly = true)
    public List<HorarioFuncionamento> daQuadra(Long quadraId) {
        return horarios.findByQuadraIdOrderByDiaSemanaAsc(quadraId);
    }

    @Transactional
    public HorarioFuncionamento criar(Long quadraId, UsuarioAutenticado usuario, HorarioFuncionamentoRequest req) {
        Quadra quadra = quadraService.buscarDoDono(quadraId, usuario);
        HorarioFuncionamento horario = new HorarioFuncionamento();
        horario.setQuadra(quadra);
        horario.setDiaSemana(req.diaSemana());
        horario.setHoraAbertura(req.horaAbertura());
        horario.setHoraFechamento(req.horaFechamento());
        try {
            return horarios.saveAndFlush(horario);
        } catch (DataIntegrityViolationException e) {
            if (ViolacaoDeIntegridade.foi(e, ViolacaoDeIntegridade.UX_HORARIO_QUADRA_DIA)) {
                throw Excecoes.conflito(CodigoErro.DIA_JA_CADASTRADO,
                        "Este dia já tem horário cadastrado. Altere o existente.");
            }
            throw e;
        }
    }

    @Transactional
    public HorarioFuncionamento atualizar(Long quadraId, Long horarioId, UsuarioAutenticado usuario,
            AtualizarHorarioRequest req) {
        quadraService.buscarDoDono(quadraId, usuario);
        HorarioFuncionamento horario = buscar(quadraId, horarioId);
        LocalTime abertura = req.horaAbertura();
        LocalTime fechamento = req.horaFechamento();
        // Ampliar é sempre permitido: só bloqueia reserva que ficaria fora da nova faixa.
        exigirSemReservas(quadraId, horario.getDiaSemana(), r -> {
            LocalTime inicio = r.getInicio().atZone(fuso).toLocalTime();
            return inicio.isBefore(abertura) || inicio.plusHours(1).isAfter(fechamento)
                    || inicio.plusHours(1).equals(LocalTime.MIDNIGHT);
        });
        horario.setHoraAbertura(abertura);
        horario.setHoraFechamento(fechamento);
        return horarios.saveAndFlush(horario);
    }

    @Transactional
    public void remover(Long quadraId, Long horarioId, UsuarioAutenticado usuario) {
        quadraService.buscarDoDono(quadraId, usuario);
        HorarioFuncionamento horario = buscar(quadraId, horarioId);
        exigirSemReservas(quadraId, horario.getDiaSemana(), r -> true);
        horarios.delete(horario);
    }

    private HorarioFuncionamento buscar(Long quadraId, Long horarioId) {
        return horarios.findByIdAndQuadraId(horarioId, quadraId)
                .orElseThrow(() -> Excecoes.naoEncontrado("Horário de funcionamento não encontrado."));
    }

    private void exigirSemReservas(Long quadraId, int diaSemana, Predicate<Reserva> afetada) {
        long afetadas = reservas.buscarAtivasFuturas(quadraId, StatusReserva.ATIVOS, relogio.instant()).stream()
                .filter(r -> diaDaSemana(r) == diaSemana)
                .filter(afetada)
                .count();
        if (afetadas > 0) {
            throw Excecoes.conflito(CodigoErro.HORARIO_COM_RESERVAS, afetadas == 1
                    ? "Existe 1 reserva ativa futura neste horário. Cancele-a antes de alterar."
                    : "Existem " + afetadas + " reservas ativas futuras neste horário. Cancele-as antes de alterar.");
        }
    }

    private int diaDaSemana(Reserva reserva) {
        ZonedDateTime local = reserva.getInicio().atZone(fuso);
        return local.getDayOfWeek().getValue();
    }
}
