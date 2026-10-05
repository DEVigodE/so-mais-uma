package br.com.puc.so_mais_uma.entity;

import java.util.List;

/** Estados da reserva (design.md D10). {@code CANCELADA} é terminal. */
public enum StatusReserva {
    PENDENTE_PAGAMENTO,
    CONFIRMADA,
    CANCELADA,
    EXPIRADA;

    /** Status que ocupam o slot, os mesmos da cláusula de {@code ux_reserva_slot_ativo}. */
    public static final List<StatusReserva> ATIVOS = List.of(PENDENTE_PAGAMENTO, CONFIRMADA);

    public boolean ativa() {
        return ATIVOS.contains(this);
    }
}
