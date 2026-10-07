package br.com.puc.so_mais_uma.integracao.pix;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.nio.charset.StandardCharsets;
import java.text.Normalizer;

/**
 * Monta o código Pix copia e cola estático (BR Code, padrão EMV-MPM do Banco Central): campos
 * {@code ID + tamanho + valor} terminados pelo CRC-16/CCITT-FALSE do próprio conteúdo.
 */
public final class PixPayloadBuilder {

    private static final String GUI_PIX = "br.gov.bcb.pix";
    private static final int MAX_NOME = 25;
    private static final int MAX_CIDADE = 15;
    private static final int MAX_TXID = 25;

    private PixPayloadBuilder() {}

    /**
     * @param valor opcional; ausente gera código sem valor fixo
     * @param txid opcional; é reduzido a {@value #MAX_TXID} caracteres alfanuméricos ou vira {@code ***}
     */
    public static String montar(String chave, String nome, String cidade, BigDecimal valor, String txid) {
        StringBuilder sb = new StringBuilder()
                .append(campo("00", "01"))
                .append(campo("26", campo("00", GUI_PIX) + campo("01", chave)))
                .append(campo("52", "0000"))
                .append(campo("53", "986"));
        if (valor != null) {
            sb.append(campo("54", valor.setScale(2, RoundingMode.HALF_UP).toPlainString()));
        }
        sb.append(campo("58", "BR"))
                .append(campo("59", limpar(nome, MAX_NOME)))
                .append(campo("60", limpar(cidade, MAX_CIDADE)))
                .append(campo("62", campo("05", referencia(txid))))
                .append("6304");
        return sb + crc16(sb.toString());
    }

    /** CRC-16/CCITT-FALSE (polinômio 0x1021, valor inicial 0xFFFF), em 4 dígitos hexadecimais maiúsculos. */
    public static String crc16(String conteudo) {
        int crc = 0xFFFF;
        for (byte b : conteudo.getBytes(StandardCharsets.UTF_8)) {
            crc ^= (b & 0xFF) << 8;
            for (int i = 0; i < 8; i++) {
                crc = (crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1;
                crc &= 0xFFFF;
            }
        }
        return String.format("%04X", crc);
    }

    private static String campo(String id, String valor) {
        int tamanho = valor.getBytes(StandardCharsets.UTF_8).length;
        if (tamanho > 99) {
            throw new IllegalArgumentException("Campo " + id + " excede 99 bytes");
        }
        return id + String.format("%02d", tamanho) + valor;
    }

    /** Remove acentos e caracteres fora do ASCII imprimível, e corta no tamanho do campo. */
    private static String limpar(String texto, int max) {
        String semAcento = Normalizer.normalize(texto.trim(), Normalizer.Form.NFD)
                .replaceAll("\\p{M}", "")
                .replaceAll("[^\\x20-\\x7E]", "");
        return semAcento.length() > max ? semAcento.substring(0, max) : semAcento;
    }

    private static String referencia(String txid) {
        if (txid == null) {
            return "***";
        }
        String alfanumerico = txid.replaceAll("[^A-Za-z0-9]", "");
        if (alfanumerico.isEmpty()) {
            return "***";
        }
        return alfanumerico.length() > MAX_TXID ? alfanumerico.substring(0, MAX_TXID) : alfanumerico;
    }
}
