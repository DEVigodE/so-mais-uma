package br.com.puc.so_mais_uma.entity;

import jakarta.persistence.Column;
import jakarta.persistence.MappedSuperclass;
import java.time.Instant;
import lombok.Getter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

/**
 * Colunas de auditoria comuns. {@code atualizado_em} é mantido pelo Hibernate nas escritas
 * pela entidade; os {@code UPDATE} condicionais dos repositórios o atualizam explicitamente.
 */
@Getter
@MappedSuperclass
public abstract class Auditavel {

    @CreationTimestamp
    @Column(name = "criado_em", nullable = false, updatable = false)
    private Instant criadoEm;

    @UpdateTimestamp
    @Column(name = "atualizado_em", nullable = false)
    private Instant atualizadoEm;
}
