package br.com.puc.so_mais_uma.service;

import br.com.puc.so_mais_uma.security.LoginBloqueioService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Ciclo de expiração, em todos os ambientes (design.md D11): reservas e cobranças vencidas em lote
 * e limpeza dos bloqueios de login vencidos. Uma reserva vencida é expirada no máximo um ciclo
 * depois do seu {@code expira_em}.
 */
@Component
public class ExpiracaoReservaJob {

    private static final Logger log = LoggerFactory.getLogger(ExpiracaoReservaJob.class);

    private final ReservaService reservaService;
    private final LoginBloqueioService bloqueio;

    public ExpiracaoReservaJob(ReservaService reservaService, LoginBloqueioService bloqueio) {
        this.reservaService = reservaService;
        this.bloqueio = bloqueio;
    }

    @Scheduled(fixedDelayString = "${app.jobs.expiracao-intervalo-ms:60000}",
            initialDelayString = "${app.jobs.expiracao-intervalo-ms:60000}")
    public void executar() {
        try {
            reservaService.expirarVencidas();
        } catch (RuntimeException e) {
            log.error("Falha no ciclo de expiração", e);
        }
        bloqueio.limparVencidos();
    }
}
