package br.com.puc.so_mais_uma.exception;

import org.springframework.http.HttpStatus;

/**
 * Catálogo estável de códigos de erro (capability {@code plataforma-backend}). Nunca renomear
 * depois da tag {@code v0.1-n1}: o consumidor decide o comportamento por este valor.
 */
public enum CodigoErro {
    VALIDACAO(HttpStatus.BAD_REQUEST, "Dados inválidos"),
    CREDENCIAL_INVALIDA(HttpStatus.UNAUTHORIZED, "Credencial inválida"),
    TOKEN_INVALIDO(HttpStatus.UNAUTHORIZED, "Não autenticado"),
    ACESSO_NEGADO(HttpStatus.FORBIDDEN, "Acesso negado"),
    NAO_ENCONTRADO(HttpStatus.NOT_FOUND, "Não encontrado"),
    EMAIL_JA_CADASTRADO(HttpStatus.CONFLICT, "Conflito"),
    HORARIO_INDISPONIVEL(HttpStatus.CONFLICT, "Conflito"),
    DIA_JA_CADASTRADO(HttpStatus.CONFLICT, "Conflito"),
    QUADRA_COM_RESERVAS(HttpStatus.CONFLICT, "Conflito"),
    HORARIO_COM_RESERVAS(HttpStatus.CONFLICT, "Conflito"),
    REGRA_NEGOCIO(HttpStatus.UNPROCESSABLE_CONTENT, "Regra de negócio"),
    LOGIN_BLOQUEADO(HttpStatus.TOO_MANY_REQUESTS, "Muitas tentativas"),
    ERRO_INTERNO(HttpStatus.INTERNAL_SERVER_ERROR, "Erro interno"),
    PAGAMENTO_INDISPONIVEL(HttpStatus.BAD_GATEWAY, "Pagamento indisponível"),
    CEP_INDISPONIVEL(HttpStatus.SERVICE_UNAVAILABLE, "CEP indisponível");

    private final HttpStatus status;
    private final String titulo;

    CodigoErro(HttpStatus status, String titulo) {
        this.status = status;
        this.titulo = titulo;
    }

    public HttpStatus status() {
        return status;
    }

    public String titulo() {
        return titulo;
    }
}
