package br.com.puc.so_mais_uma.integracao.pix.inter;

import br.com.puc.so_mais_uma.exception.IntegracaoExternaException;

/** HTTP 429 do provedor: quem chama deve pular o ciclo em vez de insistir. */
public class LimiteExcedidoException extends IntegracaoExternaException {

    public LimiteExcedidoException(String mensagem) {
        super(mensagem);
    }
}
