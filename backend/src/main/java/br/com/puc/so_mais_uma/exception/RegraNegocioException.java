package br.com.puc.so_mais_uma.exception;

/** 422 {@code REGRA_NEGOCIO} com o {@link SubcodigoErro} da regra violada. */
public class RegraNegocioException extends ApiException {

    private final SubcodigoErro subcodigo;

    public RegraNegocioException(SubcodigoErro subcodigo, String detail) {
        super(CodigoErro.REGRA_NEGOCIO, detail);
        this.subcodigo = subcodigo;
    }

    public SubcodigoErro getSubcodigo() {
        return subcodigo;
    }

    /** Acrescenta a extensão {@code reservaId} (422 {@code RESERVA_PENDENTE_EXISTENTE}). */
    public RegraNegocioException comReservaId(Long reservaId) {
        comExtensao("reservaId", reservaId);
        return this;
    }
}
