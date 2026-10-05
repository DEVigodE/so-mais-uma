package br.com.puc.so_mais_uma.exception;

/** Subcódigos das respostas 422 {@code REGRA_NEGOCIO}: identificam a regra violada. */
public enum SubcodigoErro {
    DATA_FORA_DA_JANELA,
    FORA_DO_FUNCIONAMENTO,
    RESERVA_PENDENTE_EXISTENTE,
    CANCELAMENTO_FORA_DO_PRAZO,
    TRANSICAO_INVALIDA,
    SENHA_ATUAL_INCORRETA
}
