package br.com.puc.so_mais_uma.entity;

/** Estados da cobrança Pix (design.md D10). {@code PAGO} é terminal. */
public enum StatusPagamento {
    PENDENTE,
    PAGO,
    EXPIRADO,
    CANCELADO
}
