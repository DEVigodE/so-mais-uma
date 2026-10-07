package br.com.puc.so_mais_uma.config;

import br.com.puc.so_mais_uma.exception.CodigoErro;
import io.swagger.v3.oas.annotations.OpenAPIDefinition;
import io.swagger.v3.oas.annotations.enums.SecuritySchemeType;
import io.swagger.v3.oas.annotations.info.Info;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.security.SecurityScheme;
import io.swagger.v3.oas.models.media.Content;
import io.swagger.v3.oas.models.media.MediaType;
import io.swagger.v3.oas.models.media.Schema;
import io.swagger.v3.oas.models.responses.ApiResponse;
import io.swagger.v3.oas.models.responses.ApiResponses;
import java.util.Arrays;
import java.util.Map;
import java.util.TreeMap;
import java.util.stream.Collectors;
import org.springdoc.core.customizers.OperationCustomizer;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Contrato vivo em {@code /v3/api-docs} e {@code /swagger-ui.html}: esquema {@code bearerAuth}
 * global, agrupamento por {@code @Tag} de controller e códigos de erro por operação. Desligado em
 * {@code inter-prod} por {@code springdoc.api-docs.enabled=false}.
 */
@Configuration
@ConditionalOnProperty(name = "springdoc.api-docs.enabled", havingValue = "true", matchIfMissing = true)
@OpenAPIDefinition(
        info = @Info(title = "Só mais uma — API", version = "v1",
                description = "Reserva de quadras esportivas com pagamento Pix."),
        security = @SecurityRequirement(name = "bearerAuth"))
@SecurityScheme(name = "bearerAuth", type = SecuritySchemeType.HTTP, scheme = "bearer", bearerFormat = "JWT")
public class OpenApiConfig {

    @Bean
    public OperationCustomizer errosPossiveis() {
        return (operacao, metodo) -> {
            ErrosPossiveis erros = metodo.getMethodAnnotation(ErrosPossiveis.class);
            if (erros == null) {
                return operacao;
            }
            Map<Integer, String> porStatus = Arrays.stream(erros.value())
                    .collect(Collectors.groupingBy(c -> c.status().value(), TreeMap::new,
                            Collectors.mapping(CodigoErro::name, Collectors.joining(", "))));
            ApiResponses respostas = operacao.getResponses() != null ? operacao.getResponses() : new ApiResponses();
            porStatus.forEach((status, codigos) -> respostas.addApiResponse(String.valueOf(status),
                    new ApiResponse()
                            .description("ProblemDetail com codigo: " + codigos)
                            .content(new Content().addMediaType("application/problem+json",
                                    new MediaType().schema(new Schema<>().type("object"))))));
            operacao.setResponses(respostas);
            return operacao;
        };
    }
}
