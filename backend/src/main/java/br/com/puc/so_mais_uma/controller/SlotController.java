package br.com.puc.so_mais_uma.controller;

import static br.com.puc.so_mais_uma.exception.CodigoErro.NAO_ENCONTRADO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.REGRA_NEGOCIO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.TOKEN_INVALIDO;
import static br.com.puc.so_mais_uma.exception.CodigoErro.VALIDACAO;

import br.com.puc.so_mais_uma.config.ErrosPossiveis;
import br.com.puc.so_mais_uma.dto.ReservaDtos.SlotResponse;
import br.com.puc.so_mais_uma.security.UsuarioAutenticado;
import br.com.puc.so_mais_uma.service.SlotService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.time.LocalDate;
import java.util.List;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Slots")
@RestController
@RequestMapping("${app.api-prefix}/quadras/{quadraId}/slots")
public class SlotController {

    private final SlotService slotService;

    public SlotController(SlotService slotService) {
        this.slotService = slotService;
    }

    @Operation(summary = "Grade de slots de 60 min da data (hoje até hoje + 14), calculada e não persistida")
    @ErrosPossiveis({VALIDACAO, TOKEN_INVALIDO, NAO_ENCONTRADO, REGRA_NEGOCIO})
    @GetMapping
    public List<SlotResponse> grade(@PathVariable Long quadraId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate data, UsuarioAutenticado usuario) {
        return slotService.grade(quadraId, data, usuario);
    }
}
