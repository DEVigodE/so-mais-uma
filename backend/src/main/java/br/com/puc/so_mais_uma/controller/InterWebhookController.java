package br.com.puc.so_mais_uma.controller;

import br.com.puc.so_mais_uma.config.AppProperties;
import br.com.puc.so_mais_uma.exception.Excecoes;
import br.com.puc.so_mais_uma.service.PagamentoService;
import br.com.puc.so_mais_uma.service.PagamentoService.ResultadoConfirmacao;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.time.OffsetDateTime;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import tools.jackson.databind.JsonNode;

/**
 * Receptor de notificação Pix do Inter (opcional; design.md — Open Questions). Rota pública,
 * protegida por segmento secreto na URL; responde 200 para todo corpo válido, mesmo sem efeito,
 * para o provedor não reenviar. Dados do pagador são descartados (RN05).
 */
@Tag(name = "Webhooks")
@SecurityRequirements
@RestController
@RequestMapping("${app.api-prefix}/webhooks/inter/pix")
@ConditionalOnProperty(name = "app.pix.webhook-habilitado", havingValue = "true")
public class InterWebhookController {

    private static final Logger log = LoggerFactory.getLogger(InterWebhookController.class);

    private final PagamentoService pagamentoService;
    private final byte[] segredo;

    public InterWebhookController(PagamentoService pagamentoService, AppProperties props) {
        this.pagamentoService = pagamentoService;
        String configurado = props.pix().inter() == null ? null : props.pix().inter().webhookSegredo();
        this.segredo = configurado == null || configurado.isBlank() ? null
                : configurado.getBytes(StandardCharsets.UTF_8);
    }

    @Operation(summary = "Notificação de pagamentos Pix do Banco Inter (lista JSON)")
    @PostMapping("/{segredo}")
    public ResponseEntity<Void> receber(@PathVariable("segredo") String recebido, @RequestBody JsonNode corpo) {
        if (segredo == null || !MessageDigest.isEqual(segredo, recebido.getBytes(StandardCharsets.UTF_8))) {
            throw Excecoes.naoEncontrado("Recurso não encontrado.");
        }
        if (corpo == null || !corpo.isArray()) {
            throw Excecoes.validacao("corpo", "deve ser uma lista de pagamentos");
        }
        for (JsonNode pix : corpo) {
            processar(pix);
        }
        return ResponseEntity.ok().build();
    }

    private void processar(JsonNode pix) {
        String txid = texto(pix, "txid");
        String endToEndId = texto(pix, "endToEndId");
        BigDecimal valor = valor(texto(pix, "valor"));
        if (txid == null || endToEndId == null || valor == null) {
            log.info("Notificação Pix sem txid, endToEndId ou valor válido ignorada");
            return;
        }
        ResultadoConfirmacao resultado = pagamentoService.confirmar(txid, endToEndId, valor, horario(texto(pix, "horario")));
        log.info("Webhook Inter txid={} resultado={}", txid, resultado);
    }

    private static String texto(JsonNode no, String campo) {
        JsonNode valor = no.get(campo);
        return valor == null || valor.isNull() ? null : valor.asString();
    }

    private static BigDecimal valor(String texto) {
        try {
            return texto == null ? null : new BigDecimal(texto);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private static Instant horario(String texto) {
        try {
            return texto == null ? Instant.now() : OffsetDateTime.parse(texto).toInstant();
        } catch (RuntimeException e) {
            return Instant.now();
        }
    }
}
