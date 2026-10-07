package br.com.puc.so_mais_uma.integracao.pix;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import org.junit.jupiter.api.Test;

class PixPayloadBuilderTest {

    /** Exemplo do Manual de Padrões para Iniciação do Pix (Banco Central): chave aleatória, sem valor. */
    private static final String PAYLOAD_BCB =
            "00020126580014br.gov.bcb.pix0136123e4567-e12b-12d1-a456-426655440000"
                    + "5204000053039865802BR5913Fulano de Tal6008BRASILIA62070503***63041D3D";

    @Test
    void geraOPayloadConhecidoDoManualDoBancoCentral() {
        String payload = PixPayloadBuilder.montar("123e4567-e12b-12d1-a456-426655440000", "Fulano de Tal",
                "BRASILIA", null, null);

        assertThat(payload).isEqualTo(PAYLOAD_BCB);
    }

    @Test
    void crcCcittFalseDoVetorPadrao() {
        assertThat(PixPayloadBuilder.crc16("123456789")).isEqualTo("29B1");
    }

    @Test
    void digitoVerificadorConfereComOConteudo() {
        String payload = PixPayloadBuilder.montar("somaisuma@exemplo.com", "Só Mais Uma Quadras Esportivas LTDA",
                "Belo Horizonte MG", new BigDecimal("80"), "3f9c2b7e1d4a4c6f9a8b7c6d5e4f3a2b");

        String corpo = payload.substring(0, payload.length() - 4);
        assertThat(corpo).endsWith("6304");
        assertThat(payload.substring(payload.length() - 4)).isEqualTo(PixPayloadBuilder.crc16(corpo));
        assertThat(payload).contains("540580.00");
        assertThat(payload).contains("5925So Mais Uma Quadras Espo");
        assertThat(payload).contains("6015Belo Horizonte ");
        assertThat(payload).contains("62290525" + "3f9c2b7e1d4a4c6f9a8b7c6d5");
    }
}
