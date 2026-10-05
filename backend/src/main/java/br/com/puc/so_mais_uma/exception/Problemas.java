package br.com.puc.so_mais_uma.exception;

import java.net.URI;
import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.List;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;

/**
 * Monta o {@link ProblemDetail} do contrato (RFC 9457 + {@code codigo} + {@code timestamp}).
 * Usado pelo tratador global e pelos tratadores de segurança, que rodam fora do MVC.
 */
public final class Problemas {

    private Problemas() {}

    public record Campo(String campo, String mensagem) {}

    public static ProblemDetail criar(CodigoErro codigo, String detail, String instancia, Clock relogio) {
        ProblemDetail problema = ProblemDetail.forStatusAndDetail(codigo.status(), detail);
        problema.setTitle(codigo.titulo());
        completar(problema, codigo, instancia, relogio);
        return problema;
    }

    /** Acrescenta {@code codigo}, {@code timestamp} e {@code instance} a um problema já existente. */
    public static void completar(ProblemDetail problema, CodigoErro codigo, String instancia, Clock relogio) {
        problema.setProperty("codigo", codigo.name());
        problema.setProperty("timestamp", OffsetDateTime.now(relogio));
        if (instancia != null && problema.getInstance() == null) {
            problema.setInstance(URI.create(instancia));
        }
    }

    public static void comCampos(ProblemDetail problema, List<Campo> campos) {
        problema.setProperty("campos", campos);
    }

    /** Código do catálogo para um status HTTP que não veio de uma exceção de domínio. */
    public static CodigoErro codigoPorStatus(HttpStatusCode status) {
        return switch (status.value()) {
            case 401 -> CodigoErro.TOKEN_INVALIDO;
            case 403 -> CodigoErro.ACESSO_NEGADO;
            case 404 -> CodigoErro.NAO_ENCONTRADO;
            default -> status.is4xxClientError() ? CodigoErro.VALIDACAO : CodigoErro.ERRO_INTERNO;
        };
    }
}
