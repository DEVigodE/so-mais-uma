package br.com.puc.so_mais_uma.integracao.pix;

import br.com.puc.so_mais_uma.entity.ProvedorPagamento;
import java.math.BigDecimal;
import java.time.Instant;

/**
 * Provedor Pix atrás de uma única abstração (design.md D7). A implementação ativa é escolhida pelo
 * ambiente de execução. Falhas de comunicação chegam como {@code IntegracaoExternaException}.
 */
public interface PixGateway {

    CobrancaPix criarCobranca(String txid, BigDecimal valor, int expiracaoSegundos, String descricao);

    StatusCobranca consultar(String txid);

    /** Remoção em regime de melhor esforço; quem chama registra a falha e segue. */
    void removerCobranca(String txid);

    ProvedorPagamento provedor();

    /**
     * Pede ao provedor que registre o pagamento da cobrança (apenas homologação). A confirmação
     * chega depois pelo fluxo normal de detecção.
     */
    default void simularPagamento(String txid, BigDecimal valor) {
        throw new UnsupportedOperationException("Simulação de pagamento não suportada por " + provedor());
    }

    record CobrancaPix(String pixCopiaECola, String location) {}

    /** Estado da cobrança no provedor. {@code endToEndId}, {@code valorPago} e {@code pagoEm} só quando concluída. */
    record StatusCobranca(Situacao situacao, String endToEndId, BigDecimal valorPago, Instant pagoEm) {}

    enum Situacao {
        ATIVA,
        CONCLUIDA,
        REMOVIDA_PELO_RECEBEDOR,
        REMOVIDA_PELO_PSP
    }
}
