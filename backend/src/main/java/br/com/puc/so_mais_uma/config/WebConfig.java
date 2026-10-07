package br.com.puc.so_mais_uma.config;

import br.com.puc.so_mais_uma.security.UsuarioAutenticado;
import br.com.puc.so_mais_uma.security.UsuarioAutenticadoResolver;
import io.swagger.v3.oas.models.media.StringSchema;
import java.math.BigDecimal;
import java.util.List;
import org.springdoc.core.utils.SpringDocUtils;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    static {
        // O usuário autenticado vem do token, nunca da requisição: fora do contrato documentado.
        SpringDocUtils.getConfig().addRequestWrapperToIgnore(UsuarioAutenticado.class);
        // Dinheiro trafega como string decimal com duas casas (JacksonConfig): o contrato diz o mesmo.
        SpringDocUtils.getConfig().replaceWithSchema(BigDecimal.class,
                new StringSchema().pattern("^\\d+\\.\\d{2}$").example("80.00"));
    }

    private final UsuarioAutenticadoResolver usuarioAutenticadoResolver;

    public WebConfig(UsuarioAutenticadoResolver usuarioAutenticadoResolver) {
        this.usuarioAutenticadoResolver = usuarioAutenticadoResolver;
    }

    @Override
    public void addArgumentResolvers(List<HandlerMethodArgumentResolver> resolvers) {
        resolvers.add(usuarioAutenticadoResolver);
    }
}
