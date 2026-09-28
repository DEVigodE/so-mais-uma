package br.com.puc.so_mais_uma.exception;

/**
 * Falha de um serviço externo (provedor Pix, fontes de CEP). Interna: os serviços a convertem em
 * uma resposta do catálogo ({@code PAGAMENTO_INDISPONIVEL}, {@code CEP_INDISPONIVEL}). A mensagem
 * nunca deve conter credencial.
 */
public class IntegracaoExternaException extends RuntimeException {

    public IntegracaoExternaException(String mensagem) {
        super(mensagem);
    }

    public IntegracaoExternaException(String mensagem, Throwable causa) {
        super(mensagem, causa);
    }
}
