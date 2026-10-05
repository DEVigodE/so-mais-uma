package br.com.puc.so_mais_uma.controller;

import static br.com.puc.so_mais_uma.exception.CodigoErro.ACESSO_NEGADO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.DIA_JA_CADASTRADO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.HORARIO_COM_RESERVAS;
import static br.com.puc.so_mais_uma.exception.CodigoErro.NAO_ENCONTRADO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.TOKEN_INVALIDO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.VALIDACAO;

import br.com.puc.so_mais_uma.config.ErrosPossiveis;
import br.com.puc.so_mais_uma.dto.QuadraDtos.AtualizarHorarioRequest;
import br.com.puc.so_mais_uma.dto.QuadraDtos.HorarioFuncionamentoRequest;
import br.com.puc.so_mais_uma.dto.QuadraDtos.HorarioFuncionamentoResponse;
import br.com.puc.so_mais_uma.entity.HorarioFuncionamento;
import br.com.puc.so_mais_uma.security.UsuarioAutenticado;
import br.com.puc.so_mais_uma.service.HorarioFuncionamentoService;
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
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

/** CRUD completo nº 2 (critério 3): faixas de funcionamento, uma operação por endpoint. */
@Tag(name = "HorariosFuncionamento")
@RestController
@RequestMapping("${app.api-prefix}/quadras/{quadraId}/horarios-funcionamento")
public class HorarioFuncionamentoController {

    private final HorarioFuncionamentoService horarioService;

    public HorarioFuncionamentoController(HorarioFuncionamentoService horarioService) {
        this.horarioService = horarioService;
    }

    @Operation(summary = "Lista as faixas da quadra (0 a 7; dia ausente = fechado)")
    @ErrosPossiveis({TOKEN_INVALIDO, NAO_ENCONTRADO})
    @GetMapping
    public List<HorarioFuncionamentoResponse> listar(@PathVariable Long quadraId, UsuarioAutenticado usuario) {
        return horarioService.listar(quadraId, usuario).stream().map(HorarioFuncionamentoResponse::de).toList();
    }

    @Operation(summary = "Cria a faixa de um dia da semana")
    @ErrosPossiveis({VALIDACAO, TOKEN_INVALIDO, ACESSO_NEGADO, NAO_ENCONTRADO, DIA_JA_CADASTRADO})
    @PreAuthorize("hasRole('DONO')")
    @PostMapping
    public ResponseEntity<HorarioFuncionamentoResponse> criar(@PathVariable Long quadraId,
            UsuarioAutenticado usuario, @Valid @RequestBody HorarioFuncionamentoRequest req) {
        HorarioFuncionamento horario = horarioService.criar(quadraId, usuario, req);
        var location = ServletUriComponentsBuilder.fromCurrentRequest().path("/{id}")
                .buildAndExpand(horario.getId()).toUri();
        return ResponseEntity.created(location).body(HorarioFuncionamentoResponse.de(horario));
    }

    @Operation(summary = "Altera abertura e fechamento de uma faixa")
    @ErrosPossiveis({VALIDACAO, TOKEN_INVALIDO, ACESSO_NEGADO, NAO_ENCONTRADO, HORARIO_COM_RESERVAS})
    @PreAuthorize("hasRole('DONO')")
    @PutMapping("/{horarioId}")
    public HorarioFuncionamentoResponse atualizar(@PathVariable Long quadraId, @PathVariable Long horarioId,
            UsuarioAutenticado usuario, @Valid @RequestBody AtualizarHorarioRequest req) {
        return HorarioFuncionamentoResponse.de(horarioService.atualizar(quadraId, horarioId, usuario, req));
    }

    @Operation(summary = "Remove a faixa (o dia passa a fechado)")
    @ErrosPossiveis({TOKEN_INVALIDO, ACESSO_NEGADO, NAO_ENCONTRADO, HORARIO_COM_RESERVAS})
    @PreAuthorize("hasRole('DONO')")
    @DeleteMapping("/{horarioId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void remover(@PathVariable Long quadraId, @PathVariable Long horarioId, UsuarioAutenticado usuario) {
        horarioService.remover(quadraId, horarioId, usuario);
    }
}
