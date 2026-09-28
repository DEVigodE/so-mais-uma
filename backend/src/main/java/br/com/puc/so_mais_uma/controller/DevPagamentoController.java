package br.com.puc.so_mais_uma.controller;

import static br.com.puc.so_mais_uma.exception.CodigoErro.ACESSO_NEGADO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.NAO_ENCONTRADO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.PAGAMENTO_INDISPONIVEL;
import static br.com.puc.so_mais_uma.exception.CodigoErro.REGRA_NEGOCIO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.TOKEN_INVALIDO;

import br.com.puc.so_mais_uma.config.AppProperties;
import br.com.puc.so_mais_uma.config.ErrosPossiveis;
import br.com.puc.so_mais_uma.dto.ReservaDtos.PagamentoResponse;
import br.com.puc.so_mais_uma.exception.Excecoes;
import br.com.puc.so_mais_uma.security.UsuarioAutenticado;
import br.com.puc.so_mais_uma.service.PagamentoService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Simulação de pagamento (RF21): existe apenas em {@code simulado} e {@code inter-sandbox}. Em
 * {@code inter-prod} o bean não é criado e a rota responde 404.
 */
@Tag(name = "Dev")
@RestController
@RequestMapping("${app.api-prefix}/dev/pagamentos")
@ConditionalOnProperty(name = "app.dev.endpoint-simulacao", havingValue = "true")
public class DevPagamentoController {

    private final PagamentoService pagamentoService;
    private final byte[] chaveDev;

    public DevPagamentoController(PagamentoService pagamentoService, AppProperties props) {
        this.pagamentoService = pagamentoService;
        String chave = props.dev() == null ? null : props.dev().key();
        this.chaveDev = chave == null || chave.isBlank() ? null : chave.getBytes(StandardCharsets.UTF_8);
    }

    @Operation(summary = "Simula o pagamento da cobrança (exige X-Dev-Key e ser o cliente da reserva)")
    @ErrosPossiveis({TOKEN_INVALIDO, ACESSO_NEGADO, NAO_ENCONTRADO, REGRA_NEGOCIO, PAGAMENTO_INDISPONIVEL})
    @PostMapping("/{txid}/confirmar")
    public PagamentoResponse confirmar(@PathVariable String txid, UsuarioAutenticado usuario,
            @RequestHeader(name = "X-Dev-Key", required = false) String chave) {
        if (chaveDev == null || chave == null
                || !MessageDigest.isEqual(chaveDev, chave.getBytes(StandardCharsets.UTF_8))) {
            throw Excecoes.acessoNegado();
        }
        return PagamentoResponse.de(pagamentoService.simular(txid, usuario));
    }
}
