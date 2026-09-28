package br.com.puc.so_mais_uma.config;

import br.com.puc.so_mais_uma.security.JwtService;
import br.com.puc.so_mais_uma.security.PerfilAuthoritiesConverter;
import br.com.puc.so_mais_uma.security.ProblemaSegurancaHandler;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.web.SecurityFilterChain;

/**
 * Segurança sem estado (RNF01): token de portador em toda rota não pública, perfil verificado por
 * {@code @PreAuthorize} nos controllers e propriedade verificada nos serviços.
 */
@Configuration
@EnableMethodSecurity
public class SecurityConfig {

    public static final int CUSTO_BCRYPT = 10;

    @Bean
    public SecurityFilterChain filtros(HttpSecurity http, AppProperties props, PerfilAuthoritiesConverter conversor,
            ProblemaSegurancaHandler problemas) throws Exception {
        String api = props.apiPrefix();
        http
                .csrf(csrf -> csrf.disable())
                .httpBasic(basic -> basic.disable())
                .formLogin(form -> form.disable())
                .logout(logout -> logout.disable())
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(HttpMethod.POST, api + "/auth/registrar", api + "/auth/login").permitAll()
                        .requestMatchers(HttpMethod.POST, api + "/webhooks/inter/pix/*").permitAll()
                        .requestMatchers(HttpMethod.GET, "/actuator/health").permitAll()
                        .requestMatchers("/swagger-ui.html", "/swagger-ui/**", "/v3/api-docs", "/v3/api-docs/**")
                        .permitAll()
                        .requestMatchers("/error").permitAll()
                        // Perfil conferido já no filtro, para responder 403 antes da validação do
                        // corpo (403 e não 400 para CLIENTE em rota de DONO). Os @PreAuthorize dos
                        // controllers repetem a regra e documentam cada operação.
                        .requestMatchers(HttpMethod.GET, api + "/quadras/minhas").hasRole("DONO")
                        .requestMatchers(HttpMethod.POST, api + "/quadras", api + "/quadras/*/horarios-funcionamento")
                        .hasRole("DONO")
                        .requestMatchers(HttpMethod.PUT, api + "/quadras/**").hasRole("DONO")
                        .requestMatchers(HttpMethod.DELETE, api + "/quadras/**").hasRole("DONO")
                        .requestMatchers(api + "/cep/**").hasRole("DONO")
                        .requestMatchers(HttpMethod.POST, api + "/reservas").hasRole("CLIENTE")
                        .anyRequest().authenticated())
                .oauth2ResourceServer(rs -> rs
                        .jwt(jwt -> jwt.jwtAuthenticationConverter(conversor))
                        .authenticationEntryPoint(problemas)
                        .accessDeniedHandler(problemas))
                .exceptionHandling(ex -> ex
                        .authenticationEntryPoint(problemas)
                        .accessDeniedHandler(problemas));
        return http.build();
    }

    @Bean
    public JwtDecoder jwtDecoder(JwtService jwtService) {
        return jwtService.decoder();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(CUSTO_BCRYPT);
    }
}
