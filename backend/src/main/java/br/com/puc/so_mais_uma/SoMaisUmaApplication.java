package br.com.puc.so_mais_uma;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@ConfigurationPropertiesScan
@EnableScheduling
public class SoMaisUmaApplication {

    public static void main(String[] args) {
        SpringApplication.run(SoMaisUmaApplication.class, args);
    }
}
