package br.com.puc.so_mais_uma.controller;

import static br.com.puc.so_mais_uma.exception.CodigoErro.ACESSO_NEGADO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.NAO_ENCONTRADO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.TOKEN_INVALIDO;

import br.com.puc.so_mais_uma.config.ErrosPossiveis;
import br.com.puc.so_mais_uma.dto.ReservaDtos.PagamentoResponse;
import br.com.puc.so_mais_uma.security.UsuarioAutenticado;
import br.com.puc.so_mais_uma.service.PagamentoService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Pagamentos")
@RestController
@RequestMapping("${app.api-prefix}/reservas/{reservaId}/pagamento")
public class PagamentoController {

    private final PagamentoService pagamentoService;

    public PagamentoController(PagamentoService pagamentoService) {
        this.pagamentoService = pagamentoService;
    }

    @Operation(summary = "Estado atual da cobrança, para o polling do app")
    @ErrosPossiveis({TOKEN_INVALIDO, ACESSO_NEGADO, NAO_ENCONTRADO})
    @GetMapping
    public PagamentoResponse estado(@PathVariable Long reservaId, UsuarioAutenticado usuario) {
        return PagamentoResponse.de(pagamentoService.estado(reservaId, usuario));
    }
}
