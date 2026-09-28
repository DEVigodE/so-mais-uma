package br.com.puc.so_mais_uma.support;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;

/** Relógio de teste que pode ser fixado e avançado. */
public class RelogioAjustavel extends Clock {

    public static final ZoneId SAO_PAULO = ZoneId.of("America/Sao_Paulo");

    private volatile Instant agora;
    private final ZoneId zona;

    public RelogioAjustavel(Instant agora) {
        this(agora, SAO_PAULO);
    }

    public RelogioAjustavel(Instant agora, ZoneId zona) {
        this.agora = agora;
        this.zona = zona;
    }

    public void avancar(Duration duracao) {
        agora = agora.plus(duracao);
    }

    public void fixar(Instant instante) {
        agora = instante;
    }

    @Override
    public ZoneId getZone() {
        return zona;
    }

    @Override
    public Clock withZone(ZoneId zone) {
        return new RelogioAjustavel(agora, zone);
    }

    @Override
    public Instant instant() {
        return agora;
    }
}
