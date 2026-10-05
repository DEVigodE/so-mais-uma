package br.com.puc.so_mais_uma.controller;

import static br.com.puc.so_mais_uma.exception.CodigoErro.ACESSO_NEGADO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.NAO_ENCONTRADO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.QUADRA_COM_RESERVAS;
import static br.com.puc.so_mais_uma.exception.CodigoErro.TOKEN_INVALIDO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.VALIDACAO;

import br.com.puc.so_mais_uma.config.ErrosPossiveis;
import br.com.puc.so_mais_uma.dto.QuadraDtos.QuadraRequest;
import br.com.puc.so_mais_uma.dto.QuadraDtos.QuadraResponse;
import br.com.puc.so_mais_uma.entity.Quadra;
import br.com.puc.so_mais_uma.entity.TipoEsporte;
import br.com.puc.so_mais_uma.security.UsuarioAutenticado;
import br.com.puc.so_mais_uma.service.HorarioFuncionamentoService;
import br.com.puc.so_mais_uma.service.QuadraService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

/** CRUD completo nº 1 (critério 3): quadras. */
@Tag(name = "Quadras")
@RestController
@RequestMapping("${app.api-prefix}/quadras")
public class QuadraController {

    private final QuadraService quadraService;
    private final HorarioFuncionamentoService horarioService;

    public QuadraController(QuadraService quadraService, HorarioFuncionamentoService horarioService) {
        this.quadraService = quadraService;
        this.horarioService = horarioService;
    }

    @Operation(summary = "Lista quadras ativas, com filtro opcional por esporte e cidade")
    @ErrosPossiveis({VALIDACAO, TOKEN_INVALIDO})
    @GetMapping
    public List<QuadraResponse> listar(@RequestParam(required = false) TipoEsporte esporte,
            @RequestParam(required = false) String cidade) {
        return quadraService.listar(esporte, cidade).stream().map(QuadraResponse::de).toList();
    }

    @Operation(summary = "Quadras do DONO autenticado, inclusive as inativas")
    @ErrosPossiveis({TOKEN_INVALIDO, ACESSO_NEGADO})
    @PreAuthorize("hasRole('DONO')")
    @GetMapping("/minhas")
    public List<QuadraResponse> minhas(UsuarioAutenticado usuario) {
        return quadraService.minhas(usuario.id()).stream().map(QuadraResponse::de).toList();
    }

    @Operation(summary = "Detalhe da quadra com os horários de funcionamento")
    @ErrosPossiveis({TOKEN_INVALIDO, NAO_ENCONTRADO})
    @GetMapping("/{id}")
    public QuadraResponse detalhar(@PathVariable Long id, UsuarioAutenticado usuario) {
        Quadra quadra = quadraService.buscarVisivel(id, usuario);
        return QuadraResponse.de(quadra, horarioService.daQuadra(quadra.getId()));
    }

    @Operation(summary = "Cria uma quadra; o dono é o usuário autenticado")
    @ErrosPossiveis({VALIDACAO, TOKEN_INVALIDO, ACESSO_NEGADO})
    @PreAuthorize("hasRole('DONO')")
    @PostMapping
    public ResponseEntity<QuadraResponse> criar(UsuarioAutenticado usuario, @Valid @RequestBody QuadraRequest req) {
        Quadra quadra = quadraService.criar(usuario.id(), req);
        var location = ServletUriComponentsBuilder.fromCurrentRequest().path("/{id}")
                .buildAndExpand(quadra.getId()).toUri();
        return ResponseEntity.created(location).body(QuadraResponse.de(quadra));
    }

    @Operation(summary = "Edita a quadra (apenas o dono)")
    @ErrosPossiveis({VALIDACAO, TOKEN_INVALIDO, ACESSO_NEGADO, NAO_ENCONTRADO})
    @PreAuthorize("hasRole('DONO')")
    @PutMapping("/{id}")
    public QuadraResponse atualizar(@PathVariable Long id, UsuarioAutenticado usuario,
            @Valid @RequestBody QuadraRequest req) {
        return QuadraResponse.de(quadraService.atualizar(id, usuario, req));
    }

    @Operation(summary = "Desativa a quadra (exclusão lógica)")
    @ErrosPossiveis({TOKEN_INVALIDO, ACESSO_NEGADO, NAO_ENCONTRADO, QUADRA_COM_RESERVAS})
    @PreAuthorize("hasRole('DONO')")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void desativar(@PathVariable Long id, UsuarioAutenticado usuario) {
        quadraService.desativar(id, usuario);
    }
}
