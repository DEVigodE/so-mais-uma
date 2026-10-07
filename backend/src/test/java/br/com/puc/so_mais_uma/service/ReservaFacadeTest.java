package br.com.puc.so_mais_uma.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.willReturn;

import br.com.puc.so_mais_uma.IntegracaoTestBase;
import br.com.puc.so_mais_uma.dto.ReservaDtos.CriarReservaRequest;
import br.com.puc.so_mais_uma.entity.CanceladoPor;
import br.com.puc.so_mais_uma.entity.PerfilUsuario;
import br.com.puc.so_mais_uma.entity.ProvedorPagamento;
import br.com.puc.so_mais_uma.entity.Quadra;
import br.com.puc.so_mais_uma.entity.Reserva;
import br.com.puc.so_mais_uma.entity.StatusReserva;
import br.com.puc.so_mais_uma.entity.Usuario;
import br.com.puc.so_mais_uma.exception.ApiException;
import br.com.puc.so_mais_uma.exception.CodigoErro;
import br.com.puc.so_mais_uma.exception.IntegracaoExternaException;
import br.com.puc.so_mais_uma.integracao.pix.PixGateway;
import br.com.puc.so_mais_uma.integracao.pix.PixGateway.CobrancaPix;
import br.com.puc.so_mais_uma.repository.PagamentoRepository;
import java.time.Instant;
import java.time.ZoneOffset;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

/** Compensação da criação de reserva quando o provedor Pix falha (RN17, design.md D3). */
class ReservaFacadeTest extends IntegracaoTestBase {

    @MockitoBean
    private PixGateway gateway;

    @Autowired
    private ReservaFacade facade;

    @Autowired
    private PagamentoRepository pagamentoRepository;

    private Quadra quadra;
    private Instant slot;

    @BeforeEach
    void setUp() {
        given(gateway.provedor()).willReturn(ProvedorPagamento.SIMULADO);
        quadra = novaQuadra(novoUsuario(PerfilUsuario.DONO));
        abrirTodosOsDias(quadra, 8, 22);
        slot = horaLocal(2, 19);
    }

    private CriarReservaRequest pedido() {
        return new CriarReservaRequest(quadra.getId(), slot.atOffset(ZoneOffset.ofHours(-3)), null);
    }

    @Test
    void falhaDoProvedorCancelaPorSistemaResponde502ELiberaOSlot() {
        Usuario cliente = novoUsuario(PerfilUsuario.CLIENTE);
        given(gateway.criarCobranca(anyString(), any(), anyInt(), anyString()))
                .willThrow(new IntegracaoExternaException("provedor fora do ar"));

        assertThatThrownBy(() -> facade.criar(autenticado(cliente), pedido()))
                .isInstanceOfSatisfying(ApiException.class,
                        e -> assertThat(e.getCodigo()).isEqualTo(CodigoErro.PAGAMENTO_INDISPONIVEL));

        Reserva cancelada = reservaRepository.findFirstByClienteIdAndStatus(cliente.getId(), StatusReserva.CANCELADA)
                .orElseThrow();
        assertThat(cancelada.getCanceladoPor()).isEqualTo(CanceladoPor.SISTEMA);
        assertThat(cancelada.getMotivoCancelamento()).isNotBlank();
        assertThat(pagamentoRepository.findByReservaId(cancelada.getId())).isEmpty();

        // Slot liberado: outro cliente consegue reservar assim que o provedor volta.
        willReturn(new CobrancaPix("000201...6304ABCD", null))
                .given(gateway).criarCobranca(anyString(), any(), anyInt(), anyString());
        Usuario outro = novoUsuario(PerfilUsuario.CLIENTE);
        var criada = facade.criar(autenticado(outro), pedido());
        assertThat(criada.reserva().getStatus()).isEqualTo(StatusReserva.PENDENTE_PAGAMENTO);
        assertThat(criada.pagamento()).isNotNull();
    }
}
