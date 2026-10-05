package br.com.puc.so_mais_uma.controller;

import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import br.com.puc.so_mais_uma.entity.PerfilUsuario;
import br.com.puc.so_mais_uma.exception.ApiException;
import br.com.puc.so_mais_uma.exception.CodigoErro;
import br.com.puc.so_mais_uma.integracao.cep.CepClient.EnderecoCep;
import br.com.puc.so_mais_uma.integracao.cep.CepClient.Fonte;
import br.com.puc.so_mais_uma.security.JwtService;
import br.com.puc.so_mais_uma.service.CepService;
import br.com.puc.so_mais_uma.support.WebSliceConfig;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(CepController.class)
@Import(WebSliceConfig.class)
class CepControllerTest {

    @Autowired
    private MockMvc mvc;

    @Autowired
    private JwtService jwt;

    @MockitoBean
    private CepService cepService;

    private String dono() {
        return WebSliceConfig.bearer(jwt, 1, PerfilUsuario.DONO);
    }

    @Test
    void cepEncontradoTrazEnderecoCoordenadasEFonte() throws Exception {
        given(cepService.consultar("01001000")).willReturn(new EnderecoCep("01001000", "Praça da Sé", "Sé",
                "São Paulo", "SP", -23.55, -46.63, Fonte.BRASILAPI));

        mvc.perform(get("/api/v1/cep/01001000").header("Authorization", dono()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.cidade").value("São Paulo"))
                .andExpect(jsonPath("$.latitude").value(-23.55))
                .andExpect(jsonPath("$.fonte").value("BRASILAPI"));
    }

    @Test
    void formatoInvalidoResponde400SemChamarServicoExterno() throws Exception {
        mvc.perform(get("/api/v1/cep/0100-100").header("Authorization", dono()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("VALIDACAO"));
        mvc.perform(get("/api/v1/cep/01001").header("Authorization", dono()))
                .andExpect(status().isBadRequest());
        verifyNoInteractions(cepService);
    }

    @Test
    void clienteRecebe403() throws Exception {
        mvc.perform(get("/api/v1/cep/01001000").header("Authorization", WebSliceConfig.bearer(jwt, 2, PerfilUsuario.CLIENTE)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.codigo").value("ACESSO_NEGADO"));
    }

    @Test
    void fontesIndisponiveisResponde503() throws Exception {
        given(cepService.consultar("01001000")).willThrow(new ApiException(CodigoErro.CEP_INDISPONIVEL, "x"));

        mvc.perform(get("/api/v1/cep/01001000").header("Authorization", dono()))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.codigo").value("CEP_INDISPONIVEL"));
    }
}
