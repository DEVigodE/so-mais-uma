package br.com.puc.so_mais_uma.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import br.com.puc.so_mais_uma.entity.PerfilUsuario;
import br.com.puc.so_mais_uma.exception.Excecoes;
import br.com.puc.so_mais_uma.exception.SubcodigoErro;
import br.com.puc.so_mais_uma.security.JwtService;
import br.com.puc.so_mais_uma.service.AuthService;
import br.com.puc.so_mais_uma.service.UsuarioService;
import br.com.puc.so_mais_uma.support.WebSliceConfig;
import org.hamcrest.Matchers;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

/** Formato único de erro da capability {@code plataforma-backend}. */
@WebMvcTest({AuthController.class, UsuarioController.class})
@Import(WebSliceConfig.class)
class PlataformaErroWebTest {

    @Autowired
    private MockMvc mvc;

    @Autowired
    private JwtService jwt;

    @MockitoBean
    private AuthService authService;

    @MockitoBean
    private UsuarioService usuarioService;

    @Test
    void erroDeValidacaoTrazCodigoTimestampECamposUmAUm() throws Exception {
        mvc.perform(post("/api/v1/auth/registrar").contentType(MediaType.APPLICATION_JSON).content("""
                        {"nome":"","email":"nao-e-email","senha":"curta","perfil":"CLIENTE"}"""))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("VALIDACAO"))
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.timestamp").value(Matchers.endsWith("-03:00")))
                .andExpect(jsonPath("$.campos[*].campo", Matchers.containsInAnyOrder("nome", "email", "senha")))
                .andExpect(jsonPath("$.campos[0].mensagem").isNotEmpty())
                .andExpect(jsonPath("$.subcodigo").doesNotExist())
                .andExpect(jsonPath("$.trace").doesNotExist());
    }

    @Test
    void erro422TrazCodigoRegraNegocioESubcodigo() throws Exception {
        given(usuarioService.atualizar(anyLong(), any()))
                .willThrow(Excecoes.regra(SubcodigoErro.SENHA_ATUAL_INCORRETA, "A senha atual não confere."));

        mvc.perform(put("/api/v1/usuarios/me")
                        .header("Authorization", WebSliceConfig.bearer(jwt, 1, PerfilUsuario.CLIENTE))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"nome":"Ana","senhaAtual":"Errada123","novaSenha":"Nova12345"}"""))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.codigo").value("REGRA_NEGOCIO"))
                .andExpect(jsonPath("$.subcodigo").value("SENHA_ATUAL_INCORRETA"))
                .andExpect(jsonPath("$.timestamp").exists());
    }

    @Test
    void excecaoNaoMapeadaVira500SemStackTrace() throws Exception {
        given(usuarioService.buscar(anyLong())).willThrow(new IllegalStateException("falha interna secreta"));

        mvc.perform(get("/api/v1/usuarios/me")
                        .header("Authorization", WebSliceConfig.bearer(jwt, 1, PerfilUsuario.CLIENTE)))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.codigo").value("ERRO_INTERNO"))
                .andExpect(jsonPath("$.detail").value(Matchers.not(Matchers.containsString("secreta"))))
                .andExpect(jsonPath("$.trace").doesNotExist());
    }

    @Test
    void rotaProtegidaSemTokenResponde401TokenInvalido() throws Exception {
        mvc.perform(get("/api/v1/usuarios/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.codigo").value("TOKEN_INVALIDO"));
    }

    @Test
    void tokenAdulteradoResponde401TokenInvalido() throws Exception {
        String token = WebSliceConfig.bearer(jwt, 1, PerfilUsuario.CLIENTE);
        mvc.perform(get("/api/v1/usuarios/me").header("Authorization", token.substring(0, token.length() - 3) + "abc"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.codigo").value("TOKEN_INVALIDO"));
    }
}
