package br.com.puc.so_mais_uma.security;

import br.com.puc.so_mais_uma.exception.CodigoErro;
import br.com.puc.so_mais_uma.exception.Problemas;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Clock;
import org.springframework.http.MediaType;
import org.springframework.http.ProblemDetail;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;
import tools.jackson.databind.json.JsonMapper;

/**
 * Respostas de erro geradas pela cadeia de filtros, antes do MVC: 401 {@code TOKEN_INVALIDO} para
 * token ausente, expirado, malformado ou com assinatura inválida, e 403 {@code ACESSO_NEGADO}.
 */
@Component
public class ProblemaSegurancaHandler implements AuthenticationEntryPoint, AccessDeniedHandler {

    private final JsonMapper json;
    private final Clock relogio;

    public ProblemaSegurancaHandler(JsonMapper json, Clock relogio) {
        this.json = json;
        this.relogio = relogio;
    }

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response, AuthenticationException ex)
            throws IOException {
        escrever(response, Problemas.criar(CodigoErro.TOKEN_INVALIDO,
                "Sua sessão expirou. Entre novamente.", request.getRequestURI(), relogio));
    }

    @Override
    public void handle(HttpServletRequest request, HttpServletResponse response, AccessDeniedException ex)
            throws IOException {
        escrever(response, Problemas.criar(CodigoErro.ACESSO_NEGADO,
                "Você não tem acesso a este item.", request.getRequestURI(), relogio));
    }

    private void escrever(HttpServletResponse response, ProblemDetail problema) throws IOException {
        response.setStatus(problema.getStatus());
        response.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");
        json.writeValue(response.getOutputStream(), problema);
    }
}
