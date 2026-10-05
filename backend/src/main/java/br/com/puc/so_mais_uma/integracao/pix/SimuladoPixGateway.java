package br.com.puc.so_mais_uma.integracao.pix;

import br.com.puc.so_mais_uma.config.AppProperties;
import br.com.puc.so_mais_uma.entity.ProvedorPagamento;
import java.math.BigDecimal;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

/**
 * Provedor do ambiente padrão: gera um código copia e cola estático válido com a chave, o nome e a
 * cidade configurados, sem chamar ninguém. A confirmação vem do endpoint de simulação.
 */
@Component
@Profile("simulado")
public class SimuladoPixGateway implements PixGateway {

    private final AppProperties.Simulado recebedor;

    public SimuladoPixGateway(AppProperties props) {
        this.recebedor = props.pix().simulado();
    }

    @Override
    public CobrancaPix criarCobranca(String txid, BigDecimal valor, int expiracaoSegundos, String descricao) {
        String codigo = PixPayloadBuilder.montar(recebedor.chave(), recebedor.nome(), recebedor.cidade(), valor, txid);
        return new CobrancaPix(codigo, null);
    }

    /** O estado real fica no banco; o simulado nunca é consultado (não há job de consulta). */
    @Override
    public StatusCobranca consultar(String txid) {
        return new StatusCobranca(Situacao.ATIVA, null, null, null);
    }

    @Override
    public void removerCobranca(String txid) {
        // nada a remover: a cobrança simulada só existe no banco
    }

    @Override
    public ProvedorPagamento provedor() {
        return ProvedorPagamento.SIMULADO;
    }
}
