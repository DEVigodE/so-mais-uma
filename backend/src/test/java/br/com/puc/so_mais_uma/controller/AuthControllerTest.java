package br.com.puc.so_mais_uma.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import br.com.puc.so_mais_uma.dto.AuthDtos.TokenResponse;
import br.com.puc.so_mais_uma.dto.UsuarioResponse;
import br.com.puc.so_mais_uma.entity.PerfilUsuario;
import br.com.puc.so_mais_uma.exception.ApiException;
import br.com.puc.so_mais_uma.exception.CodigoErro;
import br.com.puc.so_mais_uma.service.AuthService;
import br.com.puc.so_mais_uma.support.WebSliceConfig;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(AuthController.class)
@Import(WebSliceConfig.class)
class AuthControllerTest {

    private static final String REGISTRO_VALIDO = """
            {"nome":"Ana","email":"ana@teste.com","senha":"Senha123","perfil":"CLIENTE"}""";
    private static final String LOGIN = """
            {"email":"ana@teste.com","senha":"Senha123"}""";

    @Autowired
    private MockMvc mvc;

    @MockitoBean
    private AuthService authService;

    private TokenResponse token() {
        OffsetDateTime agora = OffsetDateTime.of(2026, 10, 10, 22, 0, 0, 0, ZoneOffset.UTC);
        return new TokenResponse("jwt", agora.plusDays(7),
                new UsuarioResponse(1L, "Ana", "ana@teste.com", null, PerfilUsuario.CLIENTE, agora));
    }

    @Test
    void registrarValidoResponde201ComTokenEUsuario() throws Exception {
        given(authService.registrar(any())).willReturn(token());

        mvc.perform(post("/api/v1/auth/registrar").contentType(MediaType.APPLICATION_JSON).content(REGISTRO_VALIDO))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.token").value("jwt"))
                .andExpect(jsonPath("$.expiraEm").value("2026-10-17T19:00:00-03:00"))
                .andExpect(jsonPath("$.usuario.perfil").value("CLIENTE"))
                .andExpect(jsonPath("$.usuario.senhaHash").doesNotExist());
    }

    @Test
    void senhaFracaResponde400ComCampoSenha() throws Exception {
        mvc.perform(post("/api/v1/auth/registrar").contentType(MediaType.APPLICATION_JSON).content("""
                        {"nome":"Ana","email":"ana@teste.com","senha":"senhasenha","perfil":"CLIENTE"}"""))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("VALIDACAO"))
                .andExpect(jsonPath("$.campos[0].campo").value("senha"));
    }

    @Test
    void emailDuplicadoResponde409() throws Exception {
        given(authService.registrar(any()))
                .willThrow(new ApiException(CodigoErro.EMAIL_JA_CADASTRADO, "Este e-mail já está cadastrado."));

        mvc.perform(post("/api/v1/auth/registrar").contentType(MediaType.APPLICATION_JSON).content(REGISTRO_VALIDO))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("EMAIL_JA_CADASTRADO"));
    }

    @Test
    void loginValidoResponde200() throws Exception {
        given(authService.login(any())).willReturn(token());

        mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON).content(LOGIN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").value("jwt"));
    }

    @Test
    void credencialInvalidaResponde401() throws Exception {
        given(authService.login(any()))
                .willThrow(new ApiException(CodigoErro.CREDENCIAL_INVALIDA, "E-mail ou senha incorretos."));

        mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON).content(LOGIN))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.codigo").value("CREDENCIAL_INVALIDA"));
    }

    @Test
    void loginBloqueadoResponde429ComTempoRestante() throws Exception {
        given(authService.login(any())).willThrow(new ApiException(CodigoErro.LOGIN_BLOQUEADO,
                "Muitas tentativas. Tente novamente em 14 minutos."));

        mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON).content(LOGIN))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.codigo").value("LOGIN_BLOQUEADO"))
                .andExpect(jsonPath("$.detail").value("Muitas tentativas. Tente novamente em 14 minutos."));
    }

    @Test
    void jsonMalformadoResponde400() throws Exception {
        mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON).content("{"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("VALIDACAO"));
    }
}
