package br.com.puc.so_mais_uma.config;

import java.time.Duration;
import java.time.ZoneId;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/** Propriedades próprias da aplicação ({@code app.*}), lidas de {@code application*.yml}. */
@ConfigurationProperties("app")
public record AppProperties(
        @DefaultValue("/api/v1") String apiPrefix,
        @DefaultValue("America/Sao_Paulo") ZoneId fuso,
        Jwt jwt,
        Reserva reserva,
        Login login,
        Cep cep,
        Dev dev,
        Pix pix) {

    public record Jwt(String secret, @DefaultValue("P7D") Duration validade) {}

    public record Reserva(@DefaultValue("PT15M") Duration prazoPagamento, @DefaultValue("14") int janelaDias) {}

    public record Login(@DefaultValue("5") int maxFalhas, @DefaultValue("PT15M") Duration bloqueio) {}

    public record Cep(
            String brasilapiUrl,
            String viacepUrl,
            @DefaultValue("PT2S") Duration connectTimeout,
            @DefaultValue("PT3S") Duration readTimeout) {}

    public record Dev(@DefaultValue("false") boolean endpointSimulacao, String key) {}

    public record Pix(
            @DefaultValue("false") boolean webhookHabilitado,
            @DefaultValue("false") boolean consultaHabilitada,
            Simulado simulado,
            Inter inter) {}

    public record Simulado(String chave, String nome, String cidade) {}

    public record Inter(
            String baseUrl,
            String clientId,
            String clientSecret,
            String certPath,
            String keyPath,
            String chave,
            String escopos,
            String webhookSegredo) {}
}
