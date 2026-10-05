package br.com.puc.so_mais_uma.security;

import br.com.puc.so_mais_uma.config.AppProperties;
import br.com.puc.so_mais_uma.exception.ApiException;
import br.com.puc.so_mais_uma.exception.CodigoErro;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Service;

/**
 * Bloqueio de login após falhas consecutivas (RF04). Em memória por decisão de projeto
 * (design.md D12): não sobrevive a reinício nem se replica entre instâncias.
 */
@Service
public class LoginBloqueioService {

    private record Estado(int falhas, Instant bloqueadoAte) {}

    private final Map<String, Estado> estados = new ConcurrentHashMap<>();
    private final int maxFalhas;
    private final Duration duracaoBloqueio;
    private final Clock relogio;

    public LoginBloqueioService(AppProperties props, Clock relogio) {
        this.maxFalhas = props.login().maxFalhas();
        this.duracaoBloqueio = props.login().bloqueio();
        this.relogio = relogio;
    }

    /** Lança 429 {@code LOGIN_BLOQUEADO} se o e-mail está bloqueado agora. */
    public void verificar(String email) {
        Estado estado = estados.get(email);
        if (estado == null || estado.bloqueadoAte() == null) {
            return;
        }
        Instant agora = relogio.instant();
        if (agora.isBefore(estado.bloqueadoAte())) {
            long minutos = Math.max(1, (Duration.between(agora, estado.bloqueadoAte()).toSeconds() + 59) / 60);
            throw new ApiException(CodigoErro.LOGIN_BLOQUEADO,
                    "Muitas tentativas. Tente novamente em " + minutos + (minutos == 1 ? " minuto." : " minutos."));
        }
        estados.remove(email, estado);
    }

    public void registrarFalha(String email) {
        Instant agora = relogio.instant();
        estados.compute(email, (chave, atual) -> {
            int falhas = (atual == null || atual.bloqueadoAte() != null ? 0 : atual.falhas()) + 1;
            return falhas >= maxFalhas ? new Estado(falhas, agora.plus(duracaoBloqueio)) : new Estado(falhas, null);
        });
    }

    public void registrarSucesso(String email) {
        estados.remove(email);
    }

    /** Remove bloqueios vencidos; chamado pelo job de expiração. */
    public void limparVencidos() {
        Instant agora = relogio.instant();
        estados.entrySet().removeIf(e -> e.getValue().bloqueadoAte() != null
                && !agora.isBefore(e.getValue().bloqueadoAte()));
    }
}
