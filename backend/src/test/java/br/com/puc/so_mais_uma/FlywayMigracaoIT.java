package br.com.puc.so_mais_uma;

import static org.assertj.core.api.Assertions.assertThat;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Prova que {@code V1__init.sql} aplica no PostgreSQL real e que o mapeamento JPA valida o
 * esquema ({@code ddl-auto=validate}): se a validação falhasse, o contexto não subiria.
 */
class FlywayMigracaoIT extends IntegracaoTestBase {

    @Autowired
    private Flyway flyway;

    @Autowired
    private JdbcTemplate jdbc;

    @Test
    void migracaoV1FoiAplicada() {
        var aplicadas = flyway.info().applied();
        assertThat(aplicadas).isNotEmpty();
        assertThat(aplicadas[0].getVersion().getVersion()).isEqualTo("1");
        assertThat(aplicadas[0].getState().isApplied()).isTrue();
    }

    @Test
    void asCincoTabelasExistem() {
        var tabelas = jdbc.queryForList(
                "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'", String.class);
        assertThat(tabelas).contains("usuario", "quadra", "horario_funcionamento", "reserva", "pagamento");
    }

    @Test
    void indiceDeExclusividadeDoSlotEParcialEUnico() {
        String definicao = jdbc.queryForObject(
                "SELECT indexdef FROM pg_indexes WHERE indexname = 'ux_reserva_slot_ativo'", String.class);
        assertThat(definicao)
                .startsWith("CREATE UNIQUE INDEX ux_reserva_slot_ativo ON public.reserva")
                .contains("(quadra_id, inicio)")
                .contains("WHERE")
                .contains("'PENDENTE_PAGAMENTO'")
                .contains("'CONFIRMADA'")
                .doesNotContain("'CANCELADA'")
                .doesNotContain("'EXPIRADA'");
    }

    @Test
    void indiceDeIdempotenciaDoPagamentoExisteComONomeUsadoNoCodigo() {
        Integer total = jdbc.queryForObject(
                "SELECT count(*) FROM pg_indexes WHERE indexname = 'ux_pagamento_end_to_end'", Integer.class);
        assertThat(total).isEqualTo(1);
    }
}
