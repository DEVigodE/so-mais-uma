package br.com.puc.so_mais_uma.exception;

/**
 * 400 {@code VALIDACAO} decidido na camada de serviço (ex.: início fora da hora cheia, motivo
 * ausente no cancelamento pelo dono), com uma entrada em {@code campos[]}.
 */
public class ValidacaoException extends ApiException {

    private final String campo;
    private final String mensagem;

    public ValidacaoException(String campo, String mensagem) {
        super(CodigoErro.VALIDACAO, "Verifique os campos destacados.");
        this.campo = campo;
        this.mensagem = mensagem;
    }

    public String getCampo() {
        return campo;
    }

    public String getMensagem() {
        return mensagem;
    }
}
