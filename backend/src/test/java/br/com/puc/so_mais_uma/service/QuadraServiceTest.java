package br.com.puc.so_mais_uma.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import br.com.puc.so_mais_uma.IntegracaoTestBase;
import br.com.puc.so_mais_uma.dto.QuadraDtos.QuadraRequest;
import br.com.puc.so_mais_uma.entity.CanceladoPor;
import br.com.puc.so_mais_uma.entity.PerfilUsuario;
import br.com.puc.so_mais_uma.entity.Quadra;
import br.com.puc.so_mais_uma.entity.Reserva;
import br.com.puc.so_mais_uma.entity.StatusReserva;
import br.com.puc.so_mais_uma.entity.TipoEsporte;
import br.com.puc.so_mais_uma.entity.Usuario;
import br.com.puc.so_mais_uma.exception.ApiException;
import br.com.puc.so_mais_uma.exception.CodigoErro;
import java.math.BigDecimal;
import java.time.Instant;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

/** Regras de quadra contra o PostgreSQL real (as consultas de reserva ativa futura são SQL). */
class QuadraServiceTest extends IntegracaoTestBase {

    @Autowired
    private QuadraService quadraService;

    private Usuario donoA;
    private Usuario donoB;
    private Usuario cliente;
    private Quadra quadraA;

    @BeforeEach
    void setUp() {
        donoA = novoUsuario(PerfilUsuario.DONO);
        donoB = novoUsuario(PerfilUsuario.DONO);
        cliente = novoUsuario(PerfilUsuario.CLIENTE);
        quadraA = novaQuadra(donoA);
    }

    private static QuadraRequest request(String nome, String preco, String cidade) {
        return new QuadraRequest(nome, TipoEsporte.VOLEI, null, new BigDecimal(preco), "30130000", "Rua A", "10",
                null, cidade, "MG", -19.93, -43.94, null);
    }

    @Test
    void criaComOUsuarioAutenticadoComoDonoENasceAtiva() {
        Quadra criada = quadraService.criar(donoB.getId(), request("Arena B", "90.00", "Belo Horizonte"));

        assertThat(criada.getDono().getId()).isEqualTo(donoB.getId());
        assertThat(criada.isAtiva()).isTrue();
    }

    @Test
    void donoANaoEditaQuadraDoDonoB() {
        assertThatThrownBy(() -> quadraService.atualizar(quadraA.getId(), autenticado(donoB),
                request("Tomada", "10.00", "BH")))
                .isInstanceOfSatisfying(ApiException.class,
                        e -> assertThat(e.getCodigo()).isEqualTo(CodigoErro.ACESSO_NEGADO));
    }

    @Test
    void quadraInexistenteResponde404() {
        assertThatThrownBy(() -> quadraService.atualizar(999_999L, autenticado(donoA), request("X", "10", "BH")))
                .isInstanceOfSatisfying(ApiException.class,
                        e -> assertThat(e.getCodigo()).isEqualTo(CodigoErro.NAO_ENCONTRADO));
    }

    @Test
    void mudarPrecoNaoAlteraReservaExistente() {
        Reserva reserva = novaReserva(quadraA, cliente, horaLocal(1, 19), StatusReserva.CONFIRMADA);

        quadraService.atualizar(quadraA.getId(), autenticado(donoA), request("Nova", "150.00", "BH"));

        assertThat(reservaRepository.findById(reserva.getId()).orElseThrow().getValor())
                .isEqualByComparingTo("80.00");
    }

    @Test
    void desativacaoELogicaSomeDaListagemEContinuaNasMinhas() {
        quadraService.desativar(quadraA.getId(), autenticado(donoA));

        assertThat(quadraRepository.findById(quadraA.getId())).get().extracting(Quadra::isAtiva).isEqualTo(false);
        assertThat(quadraService.listar(null, null)).extracting(Quadra::getId).doesNotContain(quadraA.getId());
        assertThat(quadraService.minhas(donoA.getId())).extracting(Quadra::getId).contains(quadraA.getId());
        assertThatThrownBy(() -> quadraService.buscarVisivel(quadraA.getId(), autenticado(cliente)))
                .isInstanceOfSatisfying(ApiException.class,
                        e -> assertThat(e.getCodigo()).isEqualTo(CodigoErro.NAO_ENCONTRADO));
        assertThat(quadraService.buscarVisivel(quadraA.getId(), autenticado(donoA)).getId())
                .isEqualTo(quadraA.getId());
    }

    @Test
    void reservaAtivaFuturaBloqueiaEOCancelamentoLibera() {
        Reserva reserva = novaReserva(quadraA, cliente, horaLocal(1, 19), StatusReserva.CONFIRMADA);

        assertThatThrownBy(() -> quadraService.desativar(quadraA.getId(), autenticado(donoA)))
                .isInstanceOfSatisfying(ApiException.class, e -> {
                    assertThat(e.getCodigo()).isEqualTo(CodigoErro.QUADRA_COM_RESERVAS);
                    assertThat(e.getMessage()).contains("1 reserva");
                });
        assertThat(quadraRepository.findById(quadraA.getId()).orElseThrow().isAtiva()).isTrue();

        reservaRepository.cancelar(reserva.getId(), StatusReserva.CONFIRMADA, CanceladoPor.CLIENTE, null,
                Instant.now());
        quadraService.desativar(quadraA.getId(), autenticado(donoA));

        assertThat(quadraRepository.findById(quadraA.getId()).orElseThrow().isAtiva()).isFalse();
    }

    @Test
    void reservasEncerradasOuPassadasNaoBloqueiam() {
        novaReserva(quadraA, cliente, horaLocal(1, 10), StatusReserva.EXPIRADA);
        novaReserva(quadraA, cliente, horaLocal(1, 11), StatusReserva.CANCELADA);
        novaReserva(quadraA, cliente, horaLocal(-1, 10), StatusReserva.CONFIRMADA);

        quadraService.desativar(quadraA.getId(), autenticado(donoA));

        assertThat(quadraRepository.findById(quadraA.getId()).orElseThrow().isAtiva()).isFalse();
    }

    @Test
    void filtroDeCidadeIgnoraAcentoECaixa() {
        Quadra sp = quadraService.criar(donoA.getId(), request("Arena SP", "50.00", "São Paulo"));

        assertThat(quadraService.listar(null, "sao paulo")).extracting(Quadra::getId).contains(sp.getId());
        assertThat(quadraService.listar(TipoEsporte.VOLEI, "SÃO PAULO")).extracting(Quadra::getId)
                .contains(sp.getId());
        assertThat(quadraService.listar(TipoEsporte.PADEL, "sao paulo")).extracting(Quadra::getId)
                .doesNotContain(sp.getId());
    }
}
