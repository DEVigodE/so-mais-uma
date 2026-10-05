package br.com.puc.so_mais_uma.dto;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;

/**
 * Converte instantes das entidades para a representação da API. O ajuste para o offset do fuso
 * de referência é feito na serialização ({@code spring.jackson.time-zone}).
 */
public final class Datas {

    private Datas() {}

    public static OffsetDateTime instante(Instant instante) {
        return instante == null ? null : instante.atOffset(ZoneOffset.UTC);
    }
}
