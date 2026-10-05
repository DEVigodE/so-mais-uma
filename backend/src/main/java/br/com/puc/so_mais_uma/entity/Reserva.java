package br.com.puc.so_mais_uma.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Reserva de um slot. Mudanças de status são feitas apenas por {@code UPDATE} condicional no
 * repositório (design.md D4), nunca alterando {@link #status} e salvando.
 */
@Getter
@Setter
@NoArgsConstructor
@Entity
@Table(name = "reserva")
public class Reserva extends Auditavel {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "quadra_id", nullable = false, updatable = false)
    private Quadra quadra;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "cliente_id", nullable = false, updatable = false)
    private Usuario cliente;

    @Column(nullable = false, updatable = false)
    private Instant inicio;

    @Column(nullable = false, updatable = false)
    private Instant fim;

    @Column(nullable = false, precision = 10, scale = 2, updatable = false)
    private BigDecimal valor;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private StatusReserva status;

    @Column(length = 200)
    private String observacao;

    @Column(name = "expira_em", nullable = false, updatable = false)
    private Instant expiraEm;

    @Enumerated(EnumType.STRING)
    @Column(name = "cancelado_por", length = 10)
    private CanceladoPor canceladoPor;

    @Column(name = "motivo_cancelamento", length = 200)
    private String motivoCancelamento;

    @Column(name = "cancelado_em")
    private Instant canceladoEm;
}
