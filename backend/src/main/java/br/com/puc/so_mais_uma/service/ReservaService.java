package br.com.puc.so_mais_uma.service;

import br.com.puc.so_mais_uma.config.AppProperties;
import br.com.puc.so_mais_uma.dto.ReservaDtos.CriarReservaRequest;
import br.com.puc.so_mais_uma.dto.ReservaDtos.Situacao;
import br.com.puc.so_mais_uma.entity.CanceladoPor;
import br.com.puc.so_mais_uma.entity.Pagamento;
import br.com.puc.so_mais_uma.entity.Quadra;
import br.com.puc.so_mais_uma.entity.Reserva;
import br.com.puc.so_mais_uma.entity.StatusReserva;
import br.com.puc.so_mais_uma.exception.Excecoes;
import br.com.puc.so_mais_uma.exception.SubcodigoErro;
import br.com.puc.so_mais_uma.exception.ViolacaoDeIntegridade;
import br.com.puc.so_mais_uma.repository.PagamentoRepository;
import br.com.puc.so_mais_uma.repository.ReservaRepository;
import br.com.puc.so_mais_uma.repository.UsuarioRepository;
import br.com.puc.so_mais_uma.security.UsuarioAutenticado;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Regras de reserva (RF13–RF18, RN06–RN17). A exclusividade do slot é garantida pelo índice
 * único parcial {@code ux_reserva_slot_ativo} (design.md D2) e toda transição de status é um
 * {@code UPDATE} condicional (D4).
 */
@Service
public class ReservaService {

    private static final Logger log = LoggerFactory.getLogger(ReservaService.class);
    private static final Duration ANTECEDENCIA_CANCELAMENTO_CLIENTE = Duration.ofHours(2);

    private final ReservaRepository reservas;
    private final PagamentoRepository pagamentos;
    private final UsuarioRepository usuarios;
    private final QuadraService quadraService;
    private final ReservaValidador validador;
    private final Clock relogio;
    private final ZoneId fuso;
    private final Duration prazoPagamento;

    public ReservaService(ReservaRepository reservas, PagamentoRepository pagamentos, UsuarioRepository usuarios,
            QuadraService quadraService, ReservaValidador validador, Clock relogio, ZoneId fusoReferencia,
            AppProperties props) {
        this.reservas = reservas;
        this.pagamentos = pagamentos;
        this.usuarios = usuarios;
        this.quadraService = quadraService;
        this.validador = validador;
        this.relogio = relogio;
        this.fuso = fusoReferencia;
        this.prazoPagamento = props.reserva().prazoPagamento();
    }

    // ------------------------------------------------------------------ criação

    /**
     * Transação curta: valida, grava a reserva pendente e confirma no banco antes de qualquer
     * chamada ao provedor de pagamento (D3).
     */
    @Transactional
    public Reserva criarPendente(Long clienteId, CriarReservaRequest req) {
        Quadra quadra = quadraService.buscar(req.quadraId());
        if (!quadra.isAtiva()) {
            throw Excecoes.naoEncontrado("Quadra não encontrada.");
        }
        Instant inicio = validador.validarInicio(quadra, req.inicio());
        Optional<Reserva> pendente = reservas.findFirstByClienteIdAndStatus(clienteId,
                StatusReserva.PENDENTE_PAGAMENTO);
        if (pendente.isPresent()) {
            throw Excecoes.regra(SubcodigoErro.RESERVA_PENDENTE_EXISTENTE,
                    "Você já tem uma reserva aguardando pagamento. Conclua ou cancele antes de reservar outro horário.")
                    .comReservaId(pendente.get().getId());
        }
        Instant agora = relogio.instant();
        Reserva reserva = new Reserva();
        reserva.setQuadra(quadra);
        reserva.setCliente(usuarios.getReferenceById(clienteId));
        reserva.setInicio(inicio);
        reserva.setFim(inicio.plus(1, ChronoUnit.HOURS));
        reserva.setValor(quadra.getPrecoHora());
        reserva.setStatus(StatusReserva.PENDENTE_PAGAMENTO);
        reserva.setObservacao(AuthService.vazioParaNulo(req.observacao()));
        reserva.setExpiraEm(agora.plus(prazoPagamento));
        try {
            // saveAndFlush: o INSERT precisa sair aqui, dentro do try, e não no commit (D2).
            return reservas.saveAndFlush(reserva);
        } catch (DataIntegrityViolationException e) {
            if (ViolacaoDeIntegridade.foi(e, ViolacaoDeIntegridade.UX_RESERVA_SLOT_ATIVO)) {
                throw Excecoes.horarioIndisponivel();
            }
            throw e;
        }
    }

    /** Compensação quando a cobrança não pôde ser criada (RN17): libera o slot. */
    @Transactional
    public void cancelarPorSistema(Long reservaId, String motivo) {
        int linhas = reservas.cancelar(reservaId, StatusReserva.PENDENTE_PAGAMENTO, CanceladoPor.SISTEMA, motivo,
                relogio.instant());
        if (linhas == 0) {
            log.warn("Compensação da reserva {} sem efeito: ela já não estava pendente", reservaId);
        }
    }

    // ------------------------------------------------------------------ expiração

    /** Ciclo de expiração (RN10): reservas e cobranças vencidas, em lote, na mesma transação. */
    @Transactional
    public void expirarVencidas() {
        Instant agora = relogio.instant();
        int reservasExpiradas = reservas.expirarVencidas(agora);
        int cobrancasExpiradas = pagamentos.expirarVencidos(agora);
        if (reservasExpiradas > 0 || cobrancasExpiradas > 0) {
            log.info("Expiração: {} reserva(s) e {} cobrança(s)", reservasExpiradas, cobrancasExpiradas);
        }
    }

    // ------------------------------------------------------------------ consulta

    public record ReservaComPagamento(Reserva reserva, Pagamento pagamento) {}

    @Transactional(readOnly = true)
    public ReservaComPagamento detalhar(Long id, UsuarioAutenticado usuario) {
        Reserva reserva = buscarDetalhada(id);
        if (!ehCliente(reserva, usuario) && !ehDonoDaQuadra(reserva, usuario)) {
            throw Excecoes.acessoNegado();
        }
        return new ReservaComPagamento(reserva, pagamentos.findByReservaId(id).orElse(null));
    }

    /** Reserva recém-criada com a cobrança, para a resposta da criação. */
    @Transactional(readOnly = true)
    public ReservaComPagamento carregar(Long id) {
        return new ReservaComPagamento(buscarDetalhada(id), pagamentos.findByReservaId(id).orElse(null));
    }

    /** Cliente vê as suas; dono vê as das suas quadras; sempre os últimos 12 meses, por início. */
    @Transactional(readOnly = true)
    public List<Reserva> listar(UsuarioAutenticado usuario, Situacao situacao) {
        Instant agora = relogio.instant();
        Instant desde = agora.atZone(fuso).minusMonths(12).toInstant();
        List<Reserva> todas = usuario.isDono() ? reservas.buscarDoDono(usuario.id(), desde)
                : reservas.buscarDoCliente(usuario.id(), desde);
        if (situacao == null) {
            return todas;
        }
        return todas.stream().filter(r -> proxima(r, agora) == (situacao == Situacao.PROXIMAS)).toList();
    }

    /** Agenda da quadra para o dono: da data pedida ou, sem data, as próximas. */
    @Transactional(readOnly = true)
    public List<Reserva> agendaDaQuadra(Long quadraId, UsuarioAutenticado usuario, LocalDate data) {
        quadraService.buscarDoDono(quadraId, usuario);
        if (data == null) {
            return reservas.buscarProximasDaQuadra(quadraId, StatusReserva.ATIVOS, relogio.instant());
        }
        return reservas.buscarDaQuadraNoPeriodo(quadraId, data.atStartOfDay(fuso).toInstant(),
                data.plusDays(1).atStartOfDay(fuso).toInstant());
    }

    // ------------------------------------------------------------------ edição e cancelamento

    @Transactional
    public void atualizarObservacao(Long id, UsuarioAutenticado usuario, String observacao) {
        Reserva reserva = buscarDetalhada(id);
        if (!ehCliente(reserva, usuario)) {
            throw Excecoes.acessoNegado();
        }
        int linhas = reservas.atualizarObservacao(id, AuthService.vazioParaNulo(observacao), StatusReserva.ATIVOS,
                relogio.instant());
        if (linhas == 0) {
            throw transicaoInvalida();
        }
    }

    /** Resultado do cancelamento: txid da cobrança cancelada junto, para a remoção no provedor. */
    public record Cancelamento(String txidCancelado) {}

    /**
     * Cancelamento pelo cliente (pendente a qualquer momento; confirmada até 2 h antes) ou pelo
     * dono da quadra (até o início, motivo obrigatório). Não há devolução automática (RN13, RN14).
     */
    @Transactional
    public Cancelamento cancelar(Long id, UsuarioAutenticado usuario, String motivo) {
        Reserva reserva = buscarDetalhada(id);
        boolean cliente = ehCliente(reserva, usuario);
        boolean dono = ehDonoDaQuadra(reserva, usuario);
        if (!cliente && !dono) {
            throw Excecoes.acessoNegado();
        }
        String motivoLimpo = AuthService.vazioParaNulo(motivo);
        if (dono && motivoLimpo == null) {
            throw Excecoes.validacao("motivo", "é obrigatório quando o dono cancela");
        }
        StatusReserva status = reserva.getStatus();
        if (!status.ativa()) {
            throw transicaoInvalida();
        }
        Instant agora = relogio.instant();
        boolean foraDoPrazo = dono
                ? !agora.isBefore(reserva.getInicio())
                : status == StatusReserva.CONFIRMADA
                        && agora.isAfter(reserva.getInicio().minus(ANTECEDENCIA_CANCELAMENTO_CLIENTE));
        if (foraDoPrazo) {
            throw Excecoes.regra(SubcodigoErro.CANCELAMENTO_FORA_DO_PRAZO, dono
                    ? "O dono só pode cancelar até o início da reserva."
                    : "Reservas confirmadas só podem ser canceladas até 2 horas antes do início.");
        }
        int linhas = reservas.cancelar(id, status, dono ? CanceladoPor.DONO : CanceladoPor.CLIENTE, motivoLimpo, agora);
        if (linhas == 0) {
            throw transicaoInvalida();
        }
        if (status == StatusReserva.PENDENTE_PAGAMENTO && pagamentos.cancelarDaReserva(id, agora) == 1) {
            return new Cancelamento(pagamentos.findByReservaId(id).map(Pagamento::getTxid).orElse(null));
        }
        return new Cancelamento(null);
    }

    // ------------------------------------------------------------------ apoio

    public static boolean ehCliente(Reserva reserva, UsuarioAutenticado usuario) {
        return usuario.isCliente() && reserva.getCliente().getId().equals(usuario.id());
    }

    public static boolean ehDonoDaQuadra(Reserva reserva, UsuarioAutenticado usuario) {
        return usuario.isDono() && reserva.getQuadra().pertenceA(usuario.id());
    }

    private Reserva buscarDetalhada(Long id) {
        return reservas.findDetalhadaById(id).orElseThrow(() -> Excecoes.naoEncontrado("Reserva não encontrada."));
    }

    private static boolean proxima(Reserva r, Instant agora) {
        return r.getStatus().ativa() && r.getFim().isAfter(agora);
    }

    private static RuntimeException transicaoInvalida() {
        return Excecoes.regra(SubcodigoErro.TRANSICAO_INVALIDA,
                "Esta reserva mudou de situação. Atualize para ver o estado atual.");
    }
}
