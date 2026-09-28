package br.com.puc.so_mais_uma.service;

import br.com.puc.so_mais_uma.dto.Datas;
import br.com.puc.so_mais_uma.dto.ReservaDtos.SlotResponse;
import br.com.puc.so_mais_uma.entity.HorarioFuncionamento;
import br.com.puc.so_mais_uma.entity.Quadra;
import br.com.puc.so_mais_uma.entity.StatusReserva;
import br.com.puc.so_mais_uma.entity.StatusSlot;
import br.com.puc.so_mais_uma.repository.HorarioFuncionamentoRepository;
import br.com.puc.so_mais_uma.repository.ReservaRepository;
import br.com.puc.so_mais_uma.security.UsuarioAutenticado;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Grade de slots de 60 minutos em hora cheia, calculada a cada requisição e nunca persistida
 * (design.md D8): funcionamento do dia menos reservas ativas menos horas passadas.
 *
 * <p>Dia com faixa devolve as horas da faixa (08:00–22:00 são 14 slots). Dia sem faixa devolve as
 * 24 horas do dia, todas {@code FECHADO}, para que o consumidor veja o dia fechado.
 */
@Service
public class SlotService {

    private final QuadraService quadraService;
    private final HorarioFuncionamentoRepository horarios;
    private final ReservaRepository reservas;
    private final ReservaValidador validador;
    private final Clock relogio;
    private final ZoneId fuso;

    public SlotService(QuadraService quadraService, HorarioFuncionamentoRepository horarios,
            ReservaRepository reservas, ReservaValidador validador, Clock relogio, ZoneId fusoReferencia) {
        this.quadraService = quadraService;
        this.horarios = horarios;
        this.reservas = reservas;
        this.validador = validador;
        this.relogio = relogio;
        this.fuso = fusoReferencia;
    }

    @Transactional(readOnly = true)
    public List<SlotResponse> grade(Long quadraId, LocalDate data, UsuarioAutenticado usuario) {
        Quadra quadra = quadraService.buscarVisivel(quadraId, usuario);
        validador.validarData(data);

        Optional<HorarioFuncionamento> faixa = horarios.findByQuadraIdAndDiaSemana(quadraId,
                data.getDayOfWeek().getValue());
        int primeiraHora = faixa.map(f -> f.getHoraAbertura().getHour()).orElse(0);
        int ultimaHora = faixa.map(f -> f.getHoraFechamento().getHour() - 1).orElse(23);

        Instant inicioDoDia = data.atStartOfDay(fuso).toInstant();
        Instant fimDoDia = data.plusDays(1).atStartOfDay(fuso).toInstant();
        Set<Instant> ocupados = new HashSet<>(
                reservas.buscarIniciosOcupados(quadraId, StatusReserva.ATIVOS, inicioDoDia, fimDoDia));
        Instant agora = relogio.instant();

        List<SlotResponse> grade = new ArrayList<>();
        for (int hora = primeiraHora; hora <= ultimaHora; hora++) {
            LocalTime local = LocalTime.of(hora, 0);
            Instant inicio = data.atTime(local).atZone(fuso).toInstant();
            Instant fim = inicio.plusSeconds(3600);
            StatusSlot status = classificar(faixa, local, inicio, agora, ocupados);
            grade.add(new SlotResponse(Datas.instante(inicio), Datas.instante(fim), quadra.getPrecoHora(), status));
        }
        return grade;
    }

    static StatusSlot classificar(Optional<HorarioFuncionamento> faixa, LocalTime hora, Instant inicio, Instant agora,
            Set<Instant> ocupados) {
        if (faixa.isEmpty() || !ReservaValidador.dentroDaFaixa(faixa.get(), hora)) {
            return StatusSlot.FECHADO;
        }
        if (inicio.isBefore(agora)) {
            return StatusSlot.PASSADO;
        }
        return ocupados.contains(inicio) ? StatusSlot.OCUPADO : StatusSlot.LIVRE;
    }
}
