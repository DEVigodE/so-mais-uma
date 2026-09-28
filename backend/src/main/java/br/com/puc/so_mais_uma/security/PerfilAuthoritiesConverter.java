package br.com.puc.so_mais_uma.security;

import java.util.List;
import org.springframework.core.convert.converter.Converter;
import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.stereotype.Component;

/** Claim {@code perfil} vira a autoridade {@code ROLE_CLIENTE} ou {@code ROLE_DONO}. */
@Component
public class PerfilAuthoritiesConverter implements Converter<Jwt, AbstractAuthenticationToken> {

    @Override
    public AbstractAuthenticationToken convert(Jwt jwt) {
        String perfil = jwt.getClaimAsString(JwtService.CLAIM_PERFIL);
        List<SimpleGrantedAuthority> autoridades = perfil == null ? List.of()
                : List.of(new SimpleGrantedAuthority("ROLE_" + perfil));
        return new JwtAuthenticationToken(jwt, autoridades, jwt.getSubject());
    }
}
