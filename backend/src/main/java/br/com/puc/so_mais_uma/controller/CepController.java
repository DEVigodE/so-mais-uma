package br.com.puc.so_mais_uma.controller;

import static br.com.puc.so_mais_uma.exception.CodigoErro.ACESSO_NEGADO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.CEP_INDISPONIVEL;
import static br.com.puc.so_mais_uma.exception.CodigoErro.NAO_ENCONTRADO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.TOKEN_INVALIDO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.VALIDACAO;

import br.com.puc.so_mais_uma.config.ErrosPossiveis;
import br.com.puc.so_mais_uma.integracao.cep.CepClient.EnderecoCep;
import br.com.puc.so_mais_uma.integracao.cep.CepClient.Fonte;
import br.com.puc.so_mais_uma.service.CepService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.Pattern;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Segunda API externa: BrasilAPI CEP v2 com fallback ViaCEP. */
@Tag(name = "CEP")
@RestController
@RequestMapping("${app.api-prefix}/cep")
public class CepController {

    public record CepResponse(String cep, String logradouro, String bairro, String cidade, String uf,
            Double latitude, Double longitude, Fonte fonte) {

        static CepResponse de(EnderecoCep e) {
            return new CepResponse(e.cep(), e.logradouro(), e.bairro(), e.cidade(), e.uf(), e.latitude(),
                    e.longitude(), e.fonte());
        }
    }

    private final CepService cepService;

    public CepController(CepService cepService) {
        this.cepService = cepService;
    }

    @Operation(summary = "Endereço e coordenadas a partir do CEP (8 dígitos)")
    @ErrosPossiveis({VALIDACAO, TOKEN_INVALIDO, ACESSO_NEGADO, NAO_ENCONTRADO, CEP_INDISPONIVEL})
    @PreAuthorize("hasRole('DONO')")
    @GetMapping("/{cep}")
    public CepResponse consultar(@PathVariable @Pattern(regexp = "\\d{8}", message = "deve ter 8 dígitos") String cep) {
        return CepResponse.de(cepService.consultar(cep));
    }
}
