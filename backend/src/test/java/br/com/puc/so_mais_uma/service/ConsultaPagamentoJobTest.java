package br.com.puc.so_mais_uma.service;

import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.willThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import br.com.puc.so_mais_uma.exception.IntegracaoExternaException;
import br.com.puc.so_mais_uma.integracao.pix.inter.LimiteExcedidoException;
import java.util.List;
import org.junit.jupiter.api.Test;

class ConsultaPagamentoJobTest {

    private final PagamentoService pagamentoService = mock(PagamentoService.class);
    private final ConsultaPagamentoJob job = new ConsultaPagamentoJob(pagamentoService, 10);

    @Test
    void consultaNoMaximoDezPorCiclo() {
        given(pagamentoService.pendentesParaConsulta(10)).willReturn(List.of("a", "b"));

        job.executar();

        verify(pagamentoService).pendentesParaConsulta(10);
        verify(pagamentoService).sincronizarComProvedor("a");
        verify(pagamentoService).sincronizarComProvedor("b");
    }

    @Test
    void limiteExcedidoPulaORestoDoCiclo() {
        given(pagamentoService.pendentesParaConsulta(10)).willReturn(List.of("a", "b"));
        willThrow(new LimiteExcedidoException("429")).given(pagamentoService).sincronizarComProvedor("a");

        job.executar();

        verify(pagamentoService, never()).sincronizarComProvedor("b");
    }

    @Test
    void provedorForaDoArPulaOCicloSemPropagar() {
        given(pagamentoService.pendentesParaConsulta(10)).willReturn(List.of("a", "b"));
        willThrow(new IntegracaoExternaException("fora do ar")).given(pagamentoService).sincronizarComProvedor("a");

        job.executar();

        verify(pagamentoService, never()).sincronizarComProvedor("b");
    }
}
