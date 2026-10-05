package br.com.puc.so_mais_uma.service;

import br.com.puc.so_mais_uma.exception.IntegracaoExternaException;
import br.com.puc.so_mais_uma.integracao.pix.inter.LimiteExcedidoException;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Detecção de pagamento por consulta periódica (RF20), apenas nos ambientes integrados ao
 * provedor externo: a cada 60 s, no máximo 10 cobranças pendentes, para respeitar o limite de
 * chamadas. Falha do provedor pula o resto do ciclo sem alterar status.
 */
@Component
@ConditionalOnProperty(name = "app.pix.consulta-habilitada", havingValue = "true")
public class ConsultaPagamentoJob {

    private static final Logger log = LoggerFactory.getLogger(ConsultaPagamentoJob.class);

    private final PagamentoService pagamentoService;
    private final int lote;

    public ConsultaPagamentoJob(PagamentoService pagamentoService,
            @Value("${app.jobs.consulta-pagamento-lote:10}") int lote) {
        this.pagamentoService = pagamentoService;
        this.lote = lote;
    }

    @Scheduled(fixedDelayString = "${app.jobs.consulta-pagamento-intervalo-ms:60000}",
            initialDelayString = "${app.jobs.consulta-pagamento-intervalo-ms:60000}")
    public void executar() {
        List<String> pendentes = pagamentoService.pendentesParaConsulta(lote);
        for (String txid : pendentes) {
            try {
                pagamentoService.sincronizarComProvedor(txid);
            } catch (LimiteExcedidoException e) {
                log.info("Limite de chamadas do provedor atingido; ciclo de consulta encerrado");
                return;
            } catch (IntegracaoExternaException e) {
                log.info("Provedor indisponível no ciclo de consulta ({}); nada alterado", e.getMessage());
                return;
            } catch (RuntimeException e) {
                log.error("Falha ao sincronizar a cobrança {}", txid, e);
            }
        }
    }
}
