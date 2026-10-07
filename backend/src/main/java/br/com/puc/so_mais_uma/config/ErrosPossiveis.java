package br.com.puc.so_mais_uma.config;

import br.com.puc.so_mais_uma.exception.CodigoErro;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Declara, no contrato vivo, os valores de {@code codigo} que uma operação pode devolver
 * (RNF10). {@link OpenApiConfig} converte cada um em uma resposta documentada.
 */
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface ErrosPossiveis {
    CodigoErro[] value();
}
