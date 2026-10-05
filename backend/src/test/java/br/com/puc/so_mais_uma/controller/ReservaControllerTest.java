package br.com.puc.so_mais_uma.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.BDDMockito.given;
import static org.hamcrest.Matchers.endsWith;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import br.com.puc.so_mais_uma.entity.PerfilUsuario;
import br.com.puc.so_mais_uma.entity.Quadra;
import br.com.puc.so_mais_uma.entity.Reserva;
import br.com.puc.so_mais_uma.entity.StatusReserva;
import br.com.puc.so_mais_uma.exception.Excecoes;
import br.com.puc.so_mais_uma.exception.SubcodigoErro;
import br.com.puc.so_mais_uma.security.JwtService;
import br.com.puc.so_mais_uma.service.ReservaFacade;
import br.com.puc.so_mais_uma.service.ReservaService;
import br.com.puc.so_mais_uma.service.ReservaService.ReservaComPagamento;
import br.com.puc.so_mais_uma.support.Fixtures;
import br.com.puc.so_mais_uma.support.WebSliceConfig;
import java.math.BigDecimal;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(ReservaController.class)
@Import(WebSliceConfig.class)
class ReservaControllerTest {

    private static final String CRIAR = """
            {"quadraId":3,"inicio":"2026-10-10T19:00:00-03:00","observacao":"Levamos as bolas"}""";

    @Autowired
    private MockMvc mvc;

    @Autowired
    private JwtService jwt;

    @MockitoBean
    private ReservaFacade facade;

    @MockitoBean
    private ReservaService reservaService;

    private String cliente(long id) {
        return WebSliceConfig.bearer(jwt, id, PerfilUsuario.CLIENTE);
    }

    private String dono(long id) {
        return WebSliceConfig.bearer(jwt, id, PerfilUsuario.DONO);
    }

    private static Reserva reserva() {
        Quadra q = new Quadra();
        q.setId(3L);
        q.setDono(Fixtures.usuario(9, PerfilUsuario.DONO));
        q.setNome("Arena");
        q.setLogradouro("Rua Pernambuco");
        q.setNumero("1000");
        q.setBairro("Savassi");
        q.setCidade("Belo Horizonte");
        q.setUf("MG");
        Reserva r = new Reserva();
        r.setId(42L);
        r.setQuadra(q);
        r.setCliente(Fixtures.usuario(1, PerfilUsuario.CLIENTE));
        r.setInicio(Instant.parse("2026-10-10T22:00:00Z"));
        r.setFim(Instant.parse("2026-10-10T23:00:00Z"));
        r.setValor(new BigDecimal("80.00"));
        r.setStatus(StatusReserva.PENDENTE_PAGAMENTO);
        r.setExpiraEm(Instant.parse("2026-10-08T17:20:11Z"));
        return r;
    }

    @Test
    void clienteCriaReservaCom201LocationEFormatosDoContrato() throws Exception {
        given(facade.criar(any(), any())).willReturn(new ReservaComPagamento(reserva(), null));

        mvc.perform(post("/api/v1/reservas").header("Authorization", cliente(1))
                        .contentType(MediaType.APPLICATION_JSON).content(CRIAR))
                .andExpect(status().isCreated())
                .andExpect(header().string("Location", endsWith("/api/v1/reservas/42")))
                .andExpect(jsonPath("$.inicio").value("2026-10-10T19:00:00-03:00"))
                .andExpect(jsonPath("$.valor").value("80.00"))
                .andExpect(jsonPath("$.quadraEndereco").value("Rua Pernambuco, 1000 - Savassi, Belo Horizonte/MG"))
                .andExpect(jsonPath("$.clienteNome").doesNotExist())
                .andExpect(jsonPath("$.clienteTelefone").doesNotExist());
    }

    @Test
    void donoNaoReservaNemAntesDaValidacaoDoCorpo() throws Exception {
        mvc.perform(post("/api/v1/reservas").header("Authorization", dono(9))
                        .contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.codigo").value("ACESSO_NEGADO"));
        verifyNoInteractions(facade);
    }

    @Test
    void reservaDeOutroClienteResponde403() throws Exception {
        given(reservaService.detalhar(eq(42L), any())).willThrow(Excecoes.acessoNegado());

        mvc.perform(get("/api/v1/reservas/42").header("Authorization", cliente(7)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.codigo").value("ACESSO_NEGADO"));
    }

    @Test
    void agendaDeQuadraDeOutroDonoResponde403() throws Exception {
        given(reservaService.agendaDaQuadra(eq(3L), any(), isNull())).willThrow(Excecoes.acessoNegado());

        mvc.perform(get("/api/v1/quadras/3/reservas").header("Authorization", dono(8)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.codigo").value("ACESSO_NEGADO"));
    }

    @Test
    void donoCancelandoSemMotivoResponde400() throws Exception {
        given(facade.cancelar(eq(42L), any(), isNull()))
                .willThrow(Excecoes.validacao("motivo", "é obrigatório quando o dono cancela"));

        mvc.perform(post("/api/v1/reservas/42/cancelar").header("Authorization", dono(9))
                        .contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("VALIDACAO"))
                .andExpect(jsonPath("$.campos[0].campo").value("motivo"));
    }

    @Test
    void cancelamentoForaDoPrazoResponde422ComSubcodigo() throws Exception {
        given(facade.cancelar(eq(42L), any(), any())).willThrow(
                Excecoes.regra(SubcodigoErro.CANCELAMENTO_FORA_DO_PRAZO, "fora do prazo"));

        mvc.perform(post("/api/v1/reservas/42/cancelar").header("Authorization", cliente(1)))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.subcodigo").value("CANCELAMENTO_FORA_DO_PRAZO"));
    }

    @Test
    void observacaoAcimaDe200CaracteresResponde400() throws Exception {
        mvc.perform(patch("/api/v1/reservas/42").header("Authorization", cliente(1))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"observacao\":\"" + "x".repeat(201) + "\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.campos[0].campo").value("observacao"));
    }

    @Test
    void naoExisteRotaDeExclusaoDeReserva() throws Exception {
        mvc.perform(delete("/api/v1/reservas/42")
                        .header("Authorization", cliente(1)))
                .andExpect(status().is4xxClientError());
        verifyNoInteractions(facade);
        verify(reservaService, never()).detalhar(anyLong(), any());
    }
}
