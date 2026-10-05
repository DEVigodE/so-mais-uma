package br.com.puc.so_mais_uma.support;

import br.com.puc.so_mais_uma.config.AppProperties;
import br.com.puc.so_mais_uma.config.JacksonConfig;
import br.com.puc.so_mais_uma.config.SecurityConfig;
import br.com.puc.so_mais_uma.config.TempoConfig;
import br.com.puc.so_mais_uma.config.WebConfig;
import br.com.puc.so_mais_uma.entity.PerfilUsuario;
import br.com.puc.so_mais_uma.security.JwtService;
import br.com.puc.so_mais_uma.security.PerfilAuthoritiesConverter;
import br.com.puc.so_mais_uma.security.ProblemaSegurancaHandler;
import br.com.puc.so_mais_uma.security.UsuarioAutenticadoResolver;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Import;

/**
 * Infraestrutura real de segurança, erros e serialização para os testes de fatia web: só os
 * serviços são simulados.
 */
@TestConfiguration
@EnableConfigurationProperties(AppProperties.class)
@Import({SecurityConfig.class, TempoConfig.class, JacksonConfig.class, WebConfig.class, JwtService.class,
        PerfilAuthoritiesConverter.class, ProblemaSegurancaHandler.class, UsuarioAutenticadoResolver.class})
public class WebSliceConfig {

    /** Cabeçalho {@code Authorization} com token válido para o usuário e perfil dados. */
    public static String bearer(JwtService jwt, long id, PerfilUsuario perfil) {
        return "Bearer " + jwt.emitir(Fixtures.usuario(id, perfil)).token();
    }
}
