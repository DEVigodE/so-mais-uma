package br.com.puc.so_mais_uma.exception;

import java.sql.SQLException;
import java.util.Locale;
import org.hibernate.exception.ConstraintViolationException;

/**
 * Identifica qual restrição do banco foi violada, pelo nome devolvido pelo PostgreSQL. Só a
 * restrição esperada é traduzida para um código do catálogo; qualquer outra violação continua
 * subindo e vira 500 com log completo (design.md D2).
 */
public final class ViolacaoDeIntegridade {

    public static final String UX_RESERVA_SLOT_ATIVO = "ux_reserva_slot_ativo";
    public static final String UX_USUARIO_EMAIL = "ux_usuario_email";
    public static final String UX_HORARIO_QUADRA_DIA = "ux_horario_quadra_dia";
    public static final String UX_PAGAMENTO_END_TO_END = "ux_pagamento_end_to_end";

    private ViolacaoDeIntegridade() {}

    public static boolean foi(Throwable erro, String constraint) {
        for (Throwable atual = erro; atual != null && atual.getCause() != atual; atual = atual.getCause()) {
            if (atual instanceof ConstraintViolationException cve && cve.getConstraintName() != null) {
                return cve.getConstraintName().toLowerCase(Locale.ROOT).equals(constraint);
            }
            // Mensagem do PostgreSQL: violates unique constraint "<nome>"
            if (atual instanceof SQLException sql && sql.getMessage() != null
                    && sql.getMessage().contains("constraint \"" + constraint + "\"")) {
                return true;
            }
        }
        return false;
    }
}
