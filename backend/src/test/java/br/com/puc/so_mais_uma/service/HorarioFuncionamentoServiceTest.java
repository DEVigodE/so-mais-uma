package br.com.puc.so_mais_uma.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import br.com.puc.so_mais_uma.IntegracaoTestBase;
import br.com.puc.so_mais_uma.dto.QuadraDtos.AtualizarHorarioRequest;
import br.com.puc.so_mais_uma.dto.QuadraDtos.HorarioFuncionamentoRequest;
import br.com.puc.so_mais_uma.entity.HorarioFuncionamento;
import br.com.puc.so_mais_uma.entity.PerfilUsuario;
import br.com.puc.so_mais_uma.entity.Quadra;
import br.com.puc.so_mais_uma.entity.StatusReserva;
import br.com.puc.so_mais_uma.entity.Usuario;
import br.com.puc.so_mais_uma.exception.ApiException;
import br.com.puc.so_mais_uma.exception.CodigoErro;
import java.time.Instant;
import java.time.LocalTime;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

class HorarioFuncionamentoServiceTest extends IntegracaoTestBase {

    @Autowired
    private HorarioFuncionamentoService horarioService;

    private Usuario dono;
    private Usuario outroDono;
    private Usuario cliente;
    private Quadra quadra;
    private Instant amanha21h;
    private int diaDeAmanha;

    @BeforeEach
    void setUp() {
        dono = novoUsuario(PerfilUsuario.DONO);
        outroDono = novoUsuario(PerfilUsuario.DONO);
        cliente = novoUsuario(PerfilUsuario.CLIENTE);
        quadra = novaQuadra(dono);
        amanha21h = horaLocal(1, 21);
        diaDeAmanha = amanha21h.atZone(SAO_PAULO).getDayOfWeek().getValue();
    }

    private HorarioFuncionamento criarFaixa(int dia, int abertura, int fechamento) {
        return horarioService.criar(quadra.getId(), autenticado(dono),
                new HorarioFuncionamentoRequest(dia, LocalTime.of(abertura, 0), LocalTime.of(fechamento, 0)));
    }

    private static AtualizarHorarioRequest faixa(int abertura, int fechamento) {
        return new AtualizarHorarioRequest(LocalTime.of(abertura, 0), LocalTime.of(fechamento, 0));
    }

    private static void esperarCodigo(Runnable acao, CodigoErro codigo) {
        assertThatThrownBy(acao::run).isInstanceOfSatisfying(ApiException.class,
                e -> assertThat(e.getCodigo()).isEqualTo(codigo));
    }

    @Test
    void diaDuplicadoResponde409EMantemAFaixaExistente() {
        HorarioFuncionamento existente = criarFaixa(6, 8, 22);

        esperarCodigo(() -> criarFaixa(6, 10, 12), CodigoErro.DIA_JA_CADASTRADO);

        HorarioFuncionamento relida = horarioRepository.findById(existente.getId()).orElseThrow();
        assertThat(relida.getHoraAbertura()).isEqualTo(LocalTime.of(8, 0));
    }

    @Test
    void reducaoQueDeixariaReservaForaERecusada() {
        HorarioFuncionamento h = criarFaixa(diaDeAmanha, 8, 22);
        novaReserva(quadra, cliente, amanha21h, StatusReserva.CONFIRMADA);

        esperarCodigo(() -> horarioService.atualizar(quadra.getId(), h.getId(), autenticado(dono), faixa(8, 20)),
                CodigoErro.HORARIO_COM_RESERVAS);
        esperarCodigo(() -> horarioService.atualizar(quadra.getId(), h.getId(), autenticado(dono), faixa(22, 23)),
                CodigoErro.HORARIO_COM_RESERVAS);
        assertThat(horarioRepository.findById(h.getId()).orElseThrow().getHoraFechamento())
                .isEqualTo(LocalTime.of(22, 0));
    }

    @Test
    void reducaoSemReservaAfetadaEAmpliacaoSaoPermitidas() {
        HorarioFuncionamento h = criarFaixa(diaDeAmanha, 8, 22);
        novaReserva(quadra, cliente, amanha21h, StatusReserva.PENDENTE_PAGAMENTO);

        assertThat(horarioService.atualizar(quadra.getId(), h.getId(), autenticado(dono), faixa(10, 22))
                .getHoraAbertura()).isEqualTo(LocalTime.of(10, 0));
        assertThat(horarioService.atualizar(quadra.getId(), h.getId(), autenticado(dono), faixa(6, 23))
                .getHoraFechamento()).isEqualTo(LocalTime.of(23, 0));
    }

    @Test
    void reservaEncerradaNaoBloqueiaReducao() {
        HorarioFuncionamento h = criarFaixa(diaDeAmanha, 8, 22);
        novaReserva(quadra, cliente, amanha21h, StatusReserva.EXPIRADA);

        assertThat(horarioService.atualizar(quadra.getId(), h.getId(), autenticado(dono), faixa(8, 20))
                .getHoraFechamento()).isEqualTo(LocalTime.of(20, 0));
    }

    @Test
    void remocaoBloqueadaPorReservaFuturaNoDia() {
        HorarioFuncionamento h = criarFaixa(diaDeAmanha, 8, 22);
        novaReserva(quadra, cliente, amanha21h, StatusReserva.CONFIRMADA);

        esperarCodigo(() -> horarioService.remover(quadra.getId(), h.getId(), autenticado(dono)),
                CodigoErro.HORARIO_COM_RESERVAS);
        assertThat(horarioRepository.findById(h.getId())).isPresent();
    }

    @Test
    void remocaoSemReservaLiberaODia() {
        HorarioFuncionamento h = criarFaixa(7, 8, 22);

        horarioService.remover(quadra.getId(), h.getId(), autenticado(dono));

        assertThat(horarioService.daQuadra(quadra.getId())).isEmpty();
    }

    @Test
    void outroDonoRecebe403EmTodasAsEscritas() {
        HorarioFuncionamento h = criarFaixa(1, 8, 22);

        esperarCodigo(() -> horarioService.criar(quadra.getId(), autenticado(outroDono),
                new HorarioFuncionamentoRequest(2, LocalTime.of(8, 0), LocalTime.of(9, 0))), CodigoErro.ACESSO_NEGADO);
        esperarCodigo(() -> horarioService.atualizar(quadra.getId(), h.getId(), autenticado(outroDono), faixa(9, 10)),
                CodigoErro.ACESSO_NEGADO);
        esperarCodigo(() -> horarioService.remover(quadra.getId(), h.getId(), autenticado(outroDono)),
                CodigoErro.ACESSO_NEGADO);
    }

    @Test
    void faixaDeOutraQuadraResponde404() {
        Quadra outra = novaQuadra(dono);
        HorarioFuncionamento h = criarFaixa(1, 8, 22);

        esperarCodigo(() -> horarioService.atualizar(outra.getId(), h.getId(), autenticado(dono), faixa(9, 10)),
                CodigoErro.NAO_ENCONTRADO);
    }
}
