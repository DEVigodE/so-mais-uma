package br.com.puc.so_mais_uma.config;

import java.math.BigDecimal;
import java.math.RoundingMode;
import org.springframework.boot.jackson.autoconfigure.JsonMapperBuilderCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import tools.jackson.core.JsonGenerator;
import tools.jackson.databind.SerializationContext;
import tools.jackson.databind.ValueSerializer;
import tools.jackson.databind.module.SimpleModule;

/**
 * Formatos do contrato (RNF09): dinheiro é sempre string decimal com duas casas ({@code "80.00"}).
 * Instantes saem como {@code OffsetDateTime} ajustado ao fuso de referência por
 * {@code spring.jackson.time-zone}. Coordenadas usam {@code Double} nos DTOs, então apenas
 * {@link BigDecimal} (usado só para dinheiro) passa por este serializador.
 */
@Configuration
public class JacksonConfig {

    @Bean
    public JsonMapperBuilderCustomizer dinheiroComoString() {
        SimpleModule modulo = new SimpleModule("dinheiro");
        modulo.addSerializer(BigDecimal.class, new DinheiroSerializer());
        return builder -> builder.addModule(modulo);
    }

    static class DinheiroSerializer extends ValueSerializer<BigDecimal> {
        @Override
        public void serialize(BigDecimal valor, JsonGenerator gen, SerializationContext ctxt) {
            gen.writeString(valor.setScale(2, RoundingMode.HALF_UP).toPlainString());
        }
    }
}
