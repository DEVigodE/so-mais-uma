package br.com.puc.so_mais_uma.dto;

import br.com.puc.so_mais_uma.entity.CanceladoPor;
import br.com.puc.so_mais_uma.entity.Pagamento;
import br.com.puc.so_mais_uma.entity.ProvedorPagamento;
import br.com.puc.so_mais_uma.entity.Quadra;
import br.com.puc.so_mais_uma.entity.Reserva;
import br.com.puc.so_mais_uma.entity.StatusPagamento;
import br.com.puc.so_mais_uma.entity.StatusReserva;
import br.com.puc.so_mais_uma.entity.StatusSlot;
import com.fasterxml.jackson.annotation.JsonInclude;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

/** DTOs de reserva, cobrança Pix e slot. */
public final class ReservaDtos {

    private ReservaDtos() {}

    /** Hora cheia, passado, janela e funcionamento são validados no serviço, com o relógio do backend. */
    public record CriarReservaRequest(
            @NotNull Long quadraId,
            @NotNull OffsetDateTime inicio,
            @Size(max = 200) String observacao) {}

    /** Apenas a observação é editável; outros campos enviados são ignorados. */
    public record AtualizarReservaRequest(@Size(max = 200) String observacao) {}

    /** Motivo obrigatório quando quem cancela é o DONO (validado no serviço). */
    public record CancelarReservaRequest(@Size(max = 200) String motivo) {}

    public enum Situacao { PROXIMAS, HISTORICO }

    /** Estado da cobrança. Nunca traz dados do pagador nem o identificador fim a fim. */
    public record PagamentoResponse(String txid, ProvedorPagamento provedor, StatusPagamento status, BigDecimal valor,
            String pixCopiaECola, OffsetDateTime expiraEm, OffsetDateTime pagoEm) {

        public static PagamentoResponse de(Pagamento p) {
            return p == null ? null : new PagamentoResponse(p.getTxid(), p.getProvedor(), p.getStatus(), p.getValor(),
                    p.getPixCopiaECola(), Datas.instante(p.getExpiraEm()), Datas.instante(p.getPagoEm()));
        }
    }

    /**
     * Reserva com a cobrança embutida. {@code clienteNome} e {@code clienteTelefone} são os dados
     * cadastrais do cliente e só aparecem para o DONO da quadra.
     */
    public record ReservaResponse(
            Long id,
            Long quadraId,
            String quadraNome,
            String quadraEndereco,
            Long clienteId,
            @JsonInclude(JsonInclude.Include.NON_NULL) String clienteNome,
            @JsonInclude(JsonInclude.Include.NON_NULL) String clienteTelefone,
            OffsetDateTime inicio,
            OffsetDateTime fim,
            BigDecimal valor,
            StatusReserva status,
            String observacao,
            OffsetDateTime expiraEm,
            CanceladoPor canceladoPor,
            String motivoCancelamento,
            OffsetDateTime canceladoEm,
            OffsetDateTime criadoEm,
            PagamentoResponse pagamento) {

        /** Requer {@code quadra} e {@code cliente} carregados. */
        public static ReservaResponse de(Reserva r, Pagamento pagamento, boolean incluirContatoDoCliente) {
            Quadra q = r.getQuadra();
            return new ReservaResponse(r.getId(), q.getId(), q.getNome(), endereco(q), r.getCliente().getId(),
                    incluirContatoDoCliente ? r.getCliente().getNome() : null,
                    incluirContatoDoCliente ? r.getCliente().getTelefone() : null,
                    Datas.instante(r.getInicio()), Datas.instante(r.getFim()), r.getValor(), r.getStatus(),
                    r.getObservacao(), Datas.instante(r.getExpiraEm()), r.getCanceladoPor(),
                    r.getMotivoCancelamento(), Datas.instante(r.getCanceladoEm()), Datas.instante(r.getCriadoEm()),
                    PagamentoResponse.de(pagamento));
        }

        static String endereco(Quadra q) {
            StringBuilder sb = new StringBuilder(q.getLogradouro()).append(", ").append(q.getNumero());
            if (q.getBairro() != null) {
                sb.append(" - ").append(q.getBairro());
            }
            return sb.append(", ").append(q.getCidade()).append('/').append(q.getUf()).toString();
        }
    }

    public record SlotResponse(OffsetDateTime inicio, OffsetDateTime fim, BigDecimal valor, StatusSlot status) {}
}
