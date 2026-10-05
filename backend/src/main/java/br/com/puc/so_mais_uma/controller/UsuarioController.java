package br.com.puc.so_mais_uma.controller;

import static br.com.puc.so_mais_uma.exception.CodigoErro.REGRA_NEGOCIO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.TOKEN_INVALIDO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.VALIDACAO;

import br.com.puc.so_mais_uma.config.ErrosPossiveis;
import br.com.puc.so_mais_uma.dto.AuthDtos.AtualizarUsuarioRequest;
import br.com.puc.so_mais_uma.dto.UsuarioResponse;
import br.com.puc.so_mais_uma.security.UsuarioAutenticado;
import br.com.puc.so_mais_uma.service.UsuarioService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Usuarios")
@RestController
@RequestMapping("${app.api-prefix}/usuarios")
public class UsuarioController {

    private final UsuarioService usuarioService;

    public UsuarioController(UsuarioService usuarioService) {
        this.usuarioService = usuarioService;
    }

    @Operation(summary = "Dados do usuário autenticado")
    @ErrosPossiveis({TOKEN_INVALIDO})
    @GetMapping("/me")
    public UsuarioResponse me(UsuarioAutenticado usuario) {
        return UsuarioResponse.de(usuarioService.buscar(usuario.id()));
    }

    @Operation(summary = "Edita nome, telefone e, opcionalmente, a senha (e-mail e perfil não mudam)")
    @ErrosPossiveis({VALIDACAO, TOKEN_INVALIDO, REGRA_NEGOCIO})
    @PutMapping("/me")
    public UsuarioResponse atualizar(UsuarioAutenticado usuario, @Valid @RequestBody AtualizarUsuarioRequest req) {
        return UsuarioResponse.de(usuarioService.atualizar(usuario.id(), req));
    }
}
