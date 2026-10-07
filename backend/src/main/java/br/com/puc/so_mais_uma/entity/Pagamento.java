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
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

/** Cobrança Pix de uma reserva (reserva 1 — 0..1 pagamento, design.md D3). */
@Getter
@Setter
@NoArgsConstructor
@Entity
@Table(name = "pagamento")
public class Pagamento extends Auditavel {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "reserva_id", nullable = false, updatable = false)
    private Reserva reserva;

    @Column(nullable = false, length = 35, updatable = false)
    private String txid;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10, updatable = false)
    private ProvedorPagamento provedor;

    @Column(nullable = false, precision = 10, scale = 2, updatable = false)
    private BigDecimal valor;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private StatusPagamento status;

    @JdbcTypeCode(SqlTypes.LONG32VARCHAR)
    @Column(name = "pix_copia_e_cola", nullable = false)
    private String pixCopiaECola;

    @Column(length = 255)
    private String location;

    @Column(name = "end_to_end_id", length = 32)
    private String endToEndId;

    @Column(name = "expira_em", nullable = false, updatable = false)
    private Instant expiraEm;

    @Column(name = "pago_em")
    private Instant pagoEm;
}
