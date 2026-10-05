package br.com.puc.so_mais_uma.exception;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Exceção de domínio com código do catálogo. {@code detail} é uma frase em português pronta para
 * exibição; {@code extensoes} vira propriedades adicionais do {@code ProblemDetail}.
 */
public class ApiException extends RuntimeException {

    private final CodigoErro codigo;
    private final Map<String, Object> extensoes = new LinkedHashMap<>();

    public ApiException(CodigoErro codigo, String detail) {
        super(detail);
        this.codigo = codigo;
    }

    public CodigoErro getCodigo() {
        return codigo;
    }

    public Map<String, Object> getExtensoes() {
        return extensoes;
    }

    protected ApiException comExtensao(String nome, Object valor) {
        extensoes.put(nome, valor);
        return this;
    }
}
