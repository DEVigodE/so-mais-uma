package br.com.puc.so_mais_uma.dto;

import br.com.puc.so_mais_uma.entity.HorarioFuncionamento;
import br.com.puc.so_mais_uma.entity.Quadra;
import br.com.puc.so_mais_uma.entity.TipoEsporte;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.fasterxml.jackson.annotation.JsonInclude;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.List;

/**
 * DTOs de quadra e de faixa de funcionamento. Todo limite espelha a coluna de {@code V1__init.sql},
 * para que entrada grande demais vire 400 {@code VALIDACAO} e nunca 500.
 */
public final class QuadraDtos {

    private QuadraDtos() {}

    /** Criação e edição. Não existe campo de dono: ele é sempre o usuário autenticado (RN01). */
    public record QuadraRequest(
            @NotBlank @Size(max = 100) String nome,
            @NotNull TipoEsporte tipoEsporte,
            @Size(max = 500) String descricao,
            @NotNull @DecimalMin(value = "0.00", inclusive = false, message = "deve ser maior que zero")
            @Digits(integer = 8, fraction = 2) BigDecimal precoHora,
            @NotNull @Pattern(regexp = "\\d{8}", message = "deve ter 8 dígitos") String cep,
            @NotBlank @Size(max = 150) String logradouro,
            @NotBlank @Size(max = 10) String numero,
            @Size(max = 80) String bairro,
            @NotBlank @Size(max = 80) String cidade,
            @NotNull @Pattern(regexp = "[A-Z]{2}", message = "deve ter 2 letras maiúsculas") String uf,
            @DecimalMin("-90") @DecimalMax("90") Double latitude,
            @DecimalMin("-180") @DecimalMax("180") Double longitude,
            @Size(max = 300) String fotoUrl) {

        @Schema(hidden = true)
        @AssertTrue(message = "latitude e longitude devem ser informadas juntas")
        public boolean isCoordenadas() {
            return (latitude == null) == (longitude == null);
        }
    }

    public record QuadraResponse(
            Long id,
            Long donoId,
            String nome,
            TipoEsporte tipoEsporte,
            String descricao,
            BigDecimal precoHora,
            String cep,
            String logradouro,
            String numero,
            String bairro,
            String cidade,
            String uf,
            Double latitude,
            Double longitude,
            String fotoUrl,
            boolean ativa,
            @JsonInclude(JsonInclude.Include.NON_NULL) List<HorarioFuncionamentoResponse> horariosFuncionamento,
            OffsetDateTime atualizadoEm) {

        public static QuadraResponse de(Quadra q) {
            return de(q, null);
        }

        public static QuadraResponse de(Quadra q, List<HorarioFuncionamento> horarios) {
            return new QuadraResponse(q.getId(), q.getDono().getId(), q.getNome(), q.getTipoEsporte(),
                    q.getDescricao(), q.getPrecoHora(), q.getCep(), q.getLogradouro(), q.getNumero(), q.getBairro(),
                    q.getCidade(), q.getUf(), duplo(q.getLatitude()), duplo(q.getLongitude()), q.getFotoUrl(),
                    q.isAtiva(),
                    horarios == null ? null : horarios.stream().map(HorarioFuncionamentoResponse::de).toList(),
                    Datas.instante(q.getAtualizadoEm()));
        }

        private static Double duplo(BigDecimal valor) {
            return valor == null ? null : valor.doubleValue();
        }
    }

    /** Criação de faixa: dia 1 (segunda) a 7 (domingo), horas cheias, fechamento após abertura. */
    public record HorarioFuncionamentoRequest(
            @NotNull @Min(1) @Max(7) Integer diaSemana,
            @NotNull @JsonFormat(pattern = "HH:mm") LocalTime horaAbertura,
            @NotNull @JsonFormat(pattern = "HH:mm") LocalTime horaFechamento) {

        @Schema(hidden = true)
        @AssertTrue(message = "a hora de fechamento deve ser posterior à de abertura, ambas em hora cheia")
        public boolean isFaixaValida() {
            return Faixas.valida(horaAbertura, horaFechamento);
        }
    }

    /** Alteração de faixa: o dia da semana não muda. */
    public record AtualizarHorarioRequest(
            @NotNull @JsonFormat(pattern = "HH:mm") LocalTime horaAbertura,
            @NotNull @JsonFormat(pattern = "HH:mm") LocalTime horaFechamento) {

        @Schema(hidden = true)
        @AssertTrue(message = "a hora de fechamento deve ser posterior à de abertura, ambas em hora cheia")
        public boolean isFaixaValida() {
            return Faixas.valida(horaAbertura, horaFechamento);
        }
    }

    public record HorarioFuncionamentoResponse(
            Long id,
            Long quadraId,
            Integer diaSemana,
            @JsonFormat(pattern = "HH:mm") LocalTime horaAbertura,
            @JsonFormat(pattern = "HH:mm") LocalTime horaFechamento) {

        public static HorarioFuncionamentoResponse de(HorarioFuncionamento h) {
            return new HorarioFuncionamentoResponse(h.getId(), h.getQuadra().getId(), h.getDiaSemana(),
                    h.getHoraAbertura(), h.getHoraFechamento());
        }
    }

    static final class Faixas {
        private Faixas() {}

        static boolean valida(LocalTime abertura, LocalTime fechamento) {
            if (abertura == null || fechamento == null) {
                return true; // @NotNull aponta o campo
            }
            return horaCheia(abertura) && horaCheia(fechamento) && fechamento.isAfter(abertura);
        }

        private static boolean horaCheia(LocalTime hora) {
            return hora.getMinute() == 0 && hora.getSecond() == 0 && hora.getNano() == 0;
        }
    }
}
