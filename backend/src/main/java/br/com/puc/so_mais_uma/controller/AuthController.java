package br.com.puc.so_mais_uma.controller;

import static br.com.puc.so_mais_uma.exception.CodigoErro.CREDENCIAL_INVALIDA;
import static br.com.puc.so_mais_uma.exception.CodigoErro.EMAIL_JA_CADASTRADO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.LOGIN_BLOQUEADO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.VALIDACAO;

import br.com.puc.so_mais_uma.config.ErrosPossiveis;
import br.com.puc.so_mais_uma.dto.AuthDtos.LoginRequest;
import br.com.puc.so_mais_uma.dto.AuthDtos.RegistrarRequest;
import br.com.puc.so_mais_uma.dto.AuthDtos.TokenResponse;
import br.com.puc.so_mais_uma.service.AuthService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Autenticacao")
@SecurityRequirements
@RestController
@RequestMapping("${app.api-prefix}/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @Operation(summary = "Cria a conta e já devolve o token (auto-login)")
    @ErrosPossiveis({VALIDACAO, EMAIL_JA_CADASTRADO})
    @PostMapping("/registrar")
    @ResponseStatus(HttpStatus.CREATED)
    public TokenResponse registrar(@Valid @RequestBody RegistrarRequest req) {
        return authService.registrar(req);
    }

    @Operation(summary = "Entra com e-mail e senha")
    @ErrosPossiveis({VALIDACAO, CREDENCIAL_INVALIDA, LOGIN_BLOQUEADO})
    @PostMapping("/login")
    public TokenResponse login(@Valid @RequestBody LoginRequest req) {
        return authService.login(req);
    }
}
