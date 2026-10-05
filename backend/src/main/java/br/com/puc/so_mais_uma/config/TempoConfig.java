package br.com.puc.so_mais_uma.config;

import java.time.Clock;
import java.time.ZoneId;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Fuso único de referência (RNF12) e relógio usado como "agora" por todas as regras. Expostos
 * como beans para que os testes possam fixá-los.
 */
@Configuration
public class TempoConfig {

    @Bean
    public ZoneId fusoReferencia(AppProperties props) {
        return props.fuso();
    }

    @Bean
    public Clock relogio(ZoneId fusoReferencia) {
        return Clock.system(fusoReferencia);
    }
}
