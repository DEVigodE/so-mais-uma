package br.com.puc.so_mais_uma.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import br.com.puc.so_mais_uma.service.PagamentoService;
import br.com.puc.so_mais_uma.service.PagamentoService.ResultadoConfirmacao;
import br.com.puc.so_mais_uma.support.WebSliceConfig;
import java.math.BigDecimal;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(controllers = InterWebhookController.class,
        properties = {"app.pix.webhook-habilitado=true", "app.pix.inter.webhook-segredo=segredo123"})
@Import(WebSliceConfig.class)
class InterWebhookControllerTest {

    private static final String URL = "/api/v1/webhooks/inter/pix/";
    private static final String NOTIFICACAO = """
            [{"endToEndId":"E00416968202610081707s0a1b2c3d4e5","txid":"3f9c2b7e1d4a4c6f9a8b7c6d5e4f3a2b",
              "valor":"80.00","horario":"2026-10-08T17:07:40.00-03:00",
              "infoPagador":"Reserva","componentesValor":{"original":{"valor":"80.00"}}}]""";

    @Autowired
    private MockMvc mvc;

    @MockitoBean
    private PagamentoService pagamentoService;

    @Test
    void segmentoSecretoIncorretoResponde404SemEfeito() throws Exception {
        mvc.perform(post(URL + "errado").contentType(MediaType.APPLICATION_JSON).content(NOTIFICACAO))
                .andExpect(status().isNotFound());
        verifyNoInteractions(pagamentoService);
    }

    @Test
    void corpoQueNaoELista400() throws Exception {
        mvc.perform(post(URL + "segredo123").contentType(MediaType.APPLICATION_JSON).content("{\"txid\":\"x\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("VALIDACAO"));
        mvc.perform(post(URL + "segredo123").contentType(MediaType.APPLICATION_JSON).content("não é json"))
                .andExpect(status().isBadRequest());
        verifyNoInteractions(pagamentoService);
    }

    @Test
    void txidDesconhecidoResponde200() throws Exception {
        given(pagamentoService.confirmar(anyString(), anyString(), any(), any()))
                .willReturn(ResultadoConfirmacao.DESCONHECIDO);

        mvc.perform(post(URL + "segredo123").contentType(MediaType.APPLICATION_JSON).content(NOTIFICACAO))
                .andExpect(status().isOk());
    }

    @Test
    void notificacaoValidaConfirmaSemTokenEResponde200() throws Exception {
        given(pagamentoService.confirmar(anyString(), anyString(), any(), any()))
                .willReturn(ResultadoConfirmacao.CONFIRMADO);

        mvc.perform(post(URL + "segredo123").contentType(MediaType.APPLICATION_JSON).content(NOTIFICACAO))
                .andExpect(status().isOk());

        verify(pagamentoService).confirmar(eq("3f9c2b7e1d4a4c6f9a8b7c6d5e4f3a2b"),
                eq("E00416968202610081707s0a1b2c3d4e5"), eq(new BigDecimal("80.00")), any());
    }
}
