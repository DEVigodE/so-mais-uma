package br.com.puc.so_mais_uma.controller;

import static br.com.puc.so_mais_uma.exception.CodigoErro.ACESSO_NEGADO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.HORARIO_INDISPONIVEL;
import static br.com.puc.so_mais_uma.exception.CodigoErro.NAO_ENCONTRADO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.PAGAMENTO_INDISPONIVEL;
import static br.com.puc.so_mais_uma.exception.CodigoErro.REGRA_NEGOCIO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.TOKEN_INVALIDO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.VALIDACAO;

import br.com.puc.so_mais_uma.config.ErrosPossiveis;
import br.com.puc.so_mais_uma.dto.ReservaDtos.AtualizarReservaRequest;
import br.com.puc.so_mais_uma.dto.ReservaDtos.CancelarReservaRequest;
import br.com.puc.so_mais_uma.dto.ReservaDtos.CriarReservaRequest;
import br.com.puc.so_mais_uma.dto.ReservaDtos.ReservaResponse;
import br.com.puc.so_mais_uma.dto.ReservaDtos.Situacao;
import br.com.puc.so_mais_uma.security.UsuarioAutenticado;
import br.com.puc.so_mais_uma.service.ReservaFacade;
import br.com.puc.so_mais_uma.service.ReservaService;
import br.com.puc.so_mais_uma.service.ReservaService.ReservaComPagamento;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.time.LocalDate;
import java.util.List;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

/** Reservas. Não existe rota de exclusão: reserva só muda de status (RN15). */
@Tag(name = "Reservas")
@RestController
@RequestMapping("${app.api-prefix}")
public class ReservaController {

    private final ReservaFacade facade;
    private final ReservaService reservaService;

    public ReservaController(ReservaFacade facade, ReservaService reservaService) {
        this.facade = facade;
        this.reservaService = reservaService;
    }

    @Operation(summary = "Reserva um slot (PENDENTE_PAGAMENTO) e devolve a cobrança Pix")
    @ErrosPossiveis({VALIDACAO, TOKEN_INVALIDO, ACESSO_NEGADO, NAO_ENCONTRADO, HORARIO_INDISPONIVEL, REGRA_NEGOCIO,
            PAGAMENTO_INDISPONIVEL})
    @PreAuthorize("hasRole('CLIENTE')")
    @PostMapping("/reservas")
    public ResponseEntity<ReservaResponse> criar(UsuarioAutenticado usuario,
            @Valid @RequestBody CriarReservaRequest req) {
        ReservaComPagamento criada = facade.criar(usuario, req);
        var location = ServletUriComponentsBuilder.fromCurrentRequest().path("/{id}")
                .buildAndExpand(criada.reserva().getId()).toUri();
        return ResponseEntity.created(location).body(resposta(criada, usuario));
    }

    @Operation(summary = "Reservas do cliente ou das quadras do dono, por início (últimos 12 meses)")
    @ErrosPossiveis({VALIDACAO, TOKEN_INVALIDO})
    @GetMapping("/reservas")
    public List<ReservaResponse> listar(UsuarioAutenticado usuario,
            @RequestParam(required = false) Situacao situacao) {
        return reservaService.listar(usuario, situacao).stream()
                .map(r -> ReservaResponse.de(r, null, usuario.isDono()))
                .toList();
    }

    @Operation(summary = "Detalhe da reserva com a cobrança")
    @ErrosPossiveis({TOKEN_INVALIDO, ACESSO_NEGADO, NAO_ENCONTRADO})
    @GetMapping("/reservas/{id}")
    public ReservaResponse detalhar(@PathVariable Long id, UsuarioAutenticado usuario) {
        return resposta(reservaService.detalhar(id, usuario), usuario);
    }

    @Operation(summary = "Altera apenas a observação de uma reserva ativa")
    @ErrosPossiveis({VALIDACAO, TOKEN_INVALIDO, ACESSO_NEGADO, NAO_ENCONTRADO, REGRA_NEGOCIO})
    @PatchMapping("/reservas/{id}")
    public ReservaResponse atualizar(@PathVariable Long id, UsuarioAutenticado usuario,
            @Valid @RequestBody AtualizarReservaRequest req) {
        reservaService.atualizarObservacao(id, usuario, req.observacao());
        return resposta(reservaService.detalhar(id, usuario), usuario);
    }

    @Operation(summary = "Cancela a reserva (cliente até 2 h antes se confirmada; dono até o início, com motivo)")
    @ErrosPossiveis({VALIDACAO, TOKEN_INVALIDO, ACESSO_NEGADO, NAO_ENCONTRADO, REGRA_NEGOCIO})
    @PostMapping("/reservas/{id}/cancelar")
    public ReservaResponse cancelar(@PathVariable Long id, UsuarioAutenticado usuario,
            @Valid @RequestBody(required = false) CancelarReservaRequest req) {
        return resposta(facade.cancelar(id, usuario, req == null ? null : req.motivo()), usuario);
    }

    @Operation(summary = "Agenda da quadra para o dono: da data informada ou as próximas")
    @ErrosPossiveis({VALIDACAO, TOKEN_INVALIDO, ACESSO_NEGADO, NAO_ENCONTRADO})
    @GetMapping("/quadras/{quadraId}/reservas")
    public List<ReservaResponse> agenda(@PathVariable Long quadraId, UsuarioAutenticado usuario,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate data) {
        return reservaService.agendaDaQuadra(quadraId, usuario, data).stream()
                .map(r -> ReservaResponse.de(r, null, true))
                .toList();
    }

    private static ReservaResponse resposta(ReservaComPagamento rp, UsuarioAutenticado usuario) {
        return ReservaResponse.de(rp.reserva(), rp.pagamento(), ReservaService.ehDonoDaQuadra(rp.reserva(), usuario));
    }
}
