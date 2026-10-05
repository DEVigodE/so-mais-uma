package br.com.puc.so_mais_uma.service;

import br.com.puc.so_mais_uma.config.AppProperties;
import br.com.puc.so_mais_uma.entity.HorarioFuncionamento;
import br.com.puc.so_mais_uma.entity.Quadra;
import br.com.puc.so_mais_uma.exception.Excecoes;
import br.com.puc.so_mais_uma.exception.SubcodigoErro;
import br.com.puc.so_mais_uma.repository.HorarioFuncionamentoRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.Optional;
import org.springframework.stereotype.Component;

/**
 * Regras de horário compartilhadas pela grade de slots e pela criação de reserva: hora cheia e
 * passado (400), janela de hoje até hoje + 14 dias (422) e faixa de funcionamento (422), sempre no
 * fuso de referência (RN06, RN09, RN19, RNF12).
 */
@Component
public class ReservaValidador {

    private final HorarioFuncionamentoRepository horarios;
    private final Clock relogio;
    private final ZoneId fuso;
    private final int janelaDias;

    public ReservaValidador(HorarioFuncionamentoRepository horarios, Clock relogio, ZoneId fusoReferencia,
            AppProperties props) {
        this.horarios = horarios;
        this.relogio = relogio;
        this.fuso = fusoReferencia;
        this.janelaDias = props.reserva().janelaDias();
    }

    public LocalDate hoje() {
        return LocalDate.now(relogio.withZone(fuso));
    }

    /** Data de consulta da grade: passado é 400, além de hoje + 14 é 422. */
    public void validarData(LocalDate data) {
        if (data.isBefore(hoje())) {
            throw Excecoes.validacao("data", "não pode estar no passado");
        }
        exigirDentroDaJanela(data);
    }

    /**
     * Valida o início pedido para uma quadra já confirmada como ativa.
     *
     * @return o início normalizado como instante
     */
    public Instant validarInicio(Quadra quadra, OffsetDateTime inicio) {
        ZonedDateTime local = inicio.atZoneSameInstant(fuso);
        if (local.getMinute() != 0 || local.getSecond() != 0 || local.getNano() != 0) {
            throw Excecoes.validacao("inicio", "deve estar em hora cheia");
        }
        Instant instante = local.toInstant();
        if (instante.isBefore(relogio.instant())) {
            throw Excecoes.validacao("inicio", "não pode estar no passado");
        }
        exigirDentroDaJanela(local.toLocalDate());
        Optional<HorarioFuncionamento> faixa = horarios.findByQuadraIdAndDiaSemana(quadra.getId(),
                local.getDayOfWeek().getValue());
        if (faixa.isEmpty() || !dentroDaFaixa(faixa.get(), local.toLocalTime())) {
            throw Excecoes.regra(SubcodigoErro.FORA_DO_FUNCIONAMENTO,
                    "A quadra não funciona nesse horário. Escolha outro.");
        }
        return instante;
    }

    /** O slot de uma hora começando em {@code hora} cabe inteiro na faixa. */
    public static boolean dentroDaFaixa(HorarioFuncionamento faixa, LocalTime hora) {
        return !hora.isBefore(faixa.getHoraAbertura())
                && hora.isBefore(faixa.getHoraFechamento())
                && !hora.plusHours(1).isAfter(faixa.getHoraFechamento())
                && hora.plusHours(1).isAfter(hora);
    }

    private void exigirDentroDaJanela(LocalDate data) {
        if (data.isAfter(hoje().plusDays(janelaDias))) {
            throw Excecoes.regra(SubcodigoErro.DATA_FORA_DA_JANELA,
                    "Só é possível reservar até " + janelaDias + " dias à frente.");
        }
    }
}
