package br.com.puc.so_mais_uma.service;

import br.com.puc.so_mais_uma.dto.ReservaDtos.CriarReservaRequest;
import br.com.puc.so_mais_uma.entity.Reserva;
import br.com.puc.so_mais_uma.exception.Excecoes;
import br.com.puc.so_mais_uma.exception.IntegracaoExternaException;
import br.com.puc.so_mais_uma.security.UsuarioAutenticado;
import br.com.puc.so_mais_uma.service.ReservaService.Cancelamento;
import br.com.puc.so_mais_uma.service.ReservaService.ReservaComPagamento;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * Orquestra criação e cancelamento sem transação própria (design.md D3): (1) a reserva é
 * commitada; (2) a cobrança é criada no provedor e gravada; (3) se a cobrança falha, a reserva é
 * cancelada pelo sistema e a resposta é 502. Nenhuma chamada externa roda com o slot retido numa
 * transação aberta.
 */
@Service
public class ReservaFacade {

    private static final Logger log = LoggerFactory.getLogger(ReservaFacade.class);

    private final ReservaService reservaService;
    private final PagamentoService pagamentoService;

    public ReservaFacade(ReservaService reservaService, PagamentoService pagamentoService) {
        this.reservaService = reservaService;
        this.pagamentoService = pagamentoService;
    }

    public ReservaComPagamento criar(UsuarioAutenticado cliente, CriarReservaRequest req) {
        Reserva reserva = reservaService.criarPendente(cliente.id(), req);
        try {
            pagamentoService.criarCobranca(reserva.getId(), reserva.getValor(), reserva.getExpiraEm());
        } catch (IntegracaoExternaException e) {
            log.warn("Cobrança da reserva {} não criada: {}", reserva.getId(), e.getMessage());
            reservaService.cancelarPorSistema(reserva.getId(), "Falha ao gerar a cobrança Pix");
            throw Excecoes.pagamentoIndisponivel();
        } catch (RuntimeException e) {
            reservaService.cancelarPorSistema(reserva.getId(), "Erro interno ao gerar a cobrança Pix");
            throw e;
        }
        return reservaService.carregar(reserva.getId());
    }

    /** Cancela e, se havia cobrança pendente, pede a remoção no provedor depois do commit. */
    public ReservaComPagamento cancelar(Long id, UsuarioAutenticado usuario, String motivo) {
        Cancelamento cancelamento = reservaService.cancelar(id, usuario, motivo);
        if (cancelamento.txidCancelado() != null) {
            pagamentoService.removerNoProvedor(cancelamento.txidCancelado());
        }
        return reservaService.carregar(id);
    }
}
