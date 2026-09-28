package br.com.puc.so_mais_uma.exception;

import br.com.puc.so_mais_uma.exception.Problemas.Campo;
import jakarta.servlet.http.HttpServletRequest;
import java.time.Clock;
import java.util.ArrayList;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.validation.FieldError;
import org.springframework.web.ErrorResponse;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.ServletWebRequest;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.method.annotation.HandlerMethodValidationException;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;
import org.springframework.beans.TypeMismatchException;
import tools.jackson.databind.DatabindException;

/**
 * Converte toda exceção em {@link ProblemDetail} com {@code codigo} e {@code timestamp}, mais
 * {@code subcodigo} nos 422, {@code campos[]} nos erros de validação e extensões como
 * {@code reservaId}. Nunca expõe stack trace; exceções não mapeadas vão inteiras para o log.
 */
@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);
    private static final String DETALHE_VALIDACAO = "Verifique os campos destacados.";

    private final Clock relogio;

    public GlobalExceptionHandler(Clock relogio) {
        this.relogio = relogio;
    }

    @ExceptionHandler(ValidacaoException.class)
    public ResponseEntity<ProblemDetail> validacao(ValidacaoException ex, HttpServletRequest req) {
        ProblemDetail problema = Problemas.criar(CodigoErro.VALIDACAO, ex.getMessage(), req.getRequestURI(), relogio);
        Problemas.comCampos(problema, List.of(new Campo(ex.getCampo(), ex.getMensagem())));
        return responder(problema);
    }

    @ExceptionHandler(ApiException.class)
    public ResponseEntity<ProblemDetail> dominio(ApiException ex, HttpServletRequest req) {
        ProblemDetail problema = Problemas.criar(ex.getCodigo(), ex.getMessage(), req.getRequestURI(), relogio);
        if (ex instanceof RegraNegocioException regra) {
            problema.setProperty("subcodigo", regra.getSubcodigo().name());
        }
        ex.getExtensoes().forEach(problema::setProperty);
        return responder(problema);
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ProblemDetail> acessoNegado(AccessDeniedException ex, HttpServletRequest req) {
        return responder(Problemas.criar(CodigoErro.ACESSO_NEGADO, "Você não tem acesso a este item.",
                req.getRequestURI(), relogio));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ProblemDetail> inesperada(Exception ex, HttpServletRequest req) {
        log.error("Erro não tratado em {} {}", req.getMethod(), req.getRequestURI(), ex);
        return responder(Problemas.criar(CodigoErro.ERRO_INTERNO,
                "Ocorreu um erro inesperado. Tente novamente.", req.getRequestURI(), relogio));
    }

    @Override
    protected ResponseEntity<Object> handleMethodArgumentNotValid(MethodArgumentNotValidException ex,
            HttpHeaders headers, HttpStatusCode status, WebRequest request) {
        List<Campo> campos = new ArrayList<>();
        ex.getBindingResult().getFieldErrors()
                .forEach(e -> campos.add(new Campo(e.getField(), e.getDefaultMessage())));
        ex.getBindingResult().getGlobalErrors()
                .forEach(e -> campos.add(new Campo(e.getObjectName(), e.getDefaultMessage())));
        return validacao(campos, request);
    }

    @Override
    protected ResponseEntity<Object> handleHandlerMethodValidationException(HandlerMethodValidationException ex,
            HttpHeaders headers, HttpStatusCode status, WebRequest request) {
        List<Campo> campos = new ArrayList<>();
        ex.getParameterValidationResults().forEach(resultado -> {
            String nome = resultado.getMethodParameter().getParameterName();
            resultado.getResolvableErrors().forEach(erro -> campos.add(new Campo(
                    erro instanceof FieldError fe ? fe.getField() : nome, erro.getDefaultMessage())));
        });
        return validacao(campos, request);
    }

    @Override
    protected ResponseEntity<Object> handleTypeMismatch(TypeMismatchException ex, HttpHeaders headers,
            HttpStatusCode status, WebRequest request) {
        String campo = ex.getPropertyName() != null ? ex.getPropertyName() : "parametro";
        return validacao(List.of(new Campo(campo, "valor inválido")), request);
    }

    @Override
    protected ResponseEntity<Object> handleHttpMessageNotReadable(HttpMessageNotReadableException ex,
            HttpHeaders headers, HttpStatusCode status, WebRequest request) {
        List<Campo> campos = new ArrayList<>();
        if (ex.getCause() instanceof DatabindException db && !db.getPath().isEmpty()) {
            String caminho = db.getPath().stream()
                    .map(ref -> ref.getPropertyName() != null ? ref.getPropertyName() : "[" + ref.getIndex() + "]")
                    .reduce((a, b) -> b.startsWith("[") ? a + b : a + "." + b)
                    .orElse("corpo");
            campos.add(new Campo(caminho, "valor inválido"));
        }
        return validacao(campos, request);
    }

    /** Qualquer outra exceção padrão do Spring MVC: garante {@code codigo} e {@code timestamp}. */
    @Override
    protected ResponseEntity<Object> handleExceptionInternal(Exception ex, Object body, HttpHeaders headers,
            HttpStatusCode statusCode, WebRequest request) {
        ProblemDetail problema = body instanceof ProblemDetail pd ? pd
                : ex instanceof ErrorResponse er ? er.getBody()
                : ProblemDetail.forStatus(statusCode);
        if (problema.getProperties() == null || !problema.getProperties().containsKey("codigo")) {
            CodigoErro codigo = Problemas.codigoPorStatus(statusCode);
            problema.setTitle(codigo.titulo());
            if (codigo == CodigoErro.VALIDACAO) {
                problema.setDetail(DETALHE_VALIDACAO);
            } else if (codigo == CodigoErro.NAO_ENCONTRADO) {
                problema.setDetail("Recurso não encontrado.");
            }
            Problemas.completar(problema, codigo, uri(request), relogio);
        }
        return super.handleExceptionInternal(ex, problema, headers, statusCode, request);
    }

    private ResponseEntity<Object> validacao(List<Campo> campos, WebRequest request) {
        ProblemDetail problema = Problemas.criar(CodigoErro.VALIDACAO, DETALHE_VALIDACAO, uri(request), relogio);
        Problemas.comCampos(problema, campos);
        return ResponseEntity.status(problema.getStatus()).body(problema);
    }

    private static ResponseEntity<ProblemDetail> responder(ProblemDetail problema) {
        return ResponseEntity.status(problema.getStatus()).body(problema);
    }

    private static String uri(WebRequest request) {
        return request instanceof ServletWebRequest swr ? swr.getRequest().getRequestURI() : null;
    }
}
