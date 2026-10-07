package br.com.puc.so_mais_uma.security;

import br.com.puc.so_mais_uma.entity.PerfilUsuario;
import org.springframework.core.MethodParameter;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.InvalidBearerTokenException;
import org.springframework.stereotype.Component;
import org.springframework.web.bind.support.WebDataBinderFactory;
import org.springframework.web.context.request.NativeWebRequest;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.method.support.ModelAndViewContainer;

/** Resolve parâmetros {@link UsuarioAutenticado} a partir do JWT validado da requisição. */
@Component
public class UsuarioAutenticadoResolver implements HandlerMethodArgumentResolver {

    @Override
    public boolean supportsParameter(MethodParameter parameter) {
        return UsuarioAutenticado.class.equals(parameter.getParameterType());
    }

    @Override
    public UsuarioAutenticado resolveArgument(MethodParameter parameter, ModelAndViewContainer mavContainer,
            NativeWebRequest webRequest, WebDataBinderFactory binderFactory) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof Jwt jwt)) {
            throw new InvalidBearerTokenException("Token ausente");
        }
        return new UsuarioAutenticado(
                Long.valueOf(jwt.getSubject()),
                PerfilUsuario.valueOf(jwt.getClaimAsString(JwtService.CLAIM_PERFIL)),
                jwt.getClaimAsString(JwtService.CLAIM_NOME));
    }
}
