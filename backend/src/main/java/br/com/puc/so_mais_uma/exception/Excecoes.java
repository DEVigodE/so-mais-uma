package br.com.puc.so_mais_uma.exception;

/**
 * Fábricas das exceções de domínio mais usadas. Mantém os serviços curtos e garante que cada
 * exceção carregue o {@link CodigoErro} correto.
 */
public final class Excecoes {

    private Excecoes() {}

    public static ApiException naoEncontrado(String detail) {
        return new ApiException(CodigoErro.NAO_ENCONTRADO, detail);
    }

    public static ApiException acessoNegado() {
        return new ApiException(CodigoErro.ACESSO_NEGADO, "Você não tem acesso a este item.");
    }

    public static ApiException conflito(CodigoErro codigo, String detail) {
        return new ApiException(codigo, detail);
    }

    public static ApiException horarioIndisponivel() {
        return new ApiException(CodigoErro.HORARIO_INDISPONIVEL, "Esse horário acabou de ser reservado. Escolha outro.");
    }

    public static RegraNegocioException regra(SubcodigoErro subcodigo, String detail) {
        return new RegraNegocioException(subcodigo, detail);
    }

    public static ApiException pagamentoIndisponivel() {
        return new ApiException(CodigoErro.PAGAMENTO_INDISPONIVEL,
                "Não foi possível gerar a cobrança, tente novamente.");
    }

    public static ValidacaoException validacao(String campo, String mensagem) {
        return new ValidacaoException(campo, mensagem);
    }
}
