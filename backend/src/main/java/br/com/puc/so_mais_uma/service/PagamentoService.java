package br.com.puc.so_mais_uma.service;

import br.com.puc.so_mais_uma.entity.Pagamento;
import br.com.puc.so_mais_uma.entity.ProvedorPagamento;
import br.com.puc.so_mais_uma.entity.Reserva;
import br.com.puc.so_mais_uma.entity.StatusPagamento;
import br.com.puc.so_mais_uma.entity.StatusReserva;
import br.com.puc.so_mais_uma.exception.Excecoes;
import br.com.puc.so_mais_uma.exception.IntegracaoExternaException;
import br.com.puc.so_mais_uma.exception.SubcodigoErro;
import br.com.puc.so_mais_uma.exception.ViolacaoDeIntegridade;
import br.com.puc.so_mais_uma.integracao.pix.PixGateway;
import br.com.puc.so_mais_uma.integracao.pix.PixGateway.CobrancaPix;
import br.com.puc.so_mais_uma.repository.PagamentoRepository;
import br.com.puc.so_mais_uma.repository.ReservaRepository;
import br.com.puc.so_mais_uma.security.UsuarioAutenticado;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Cobrança Pix da reserva (RF19–RF21) e o ponto único de confirmação de pagamento (design.md D5),
 * usado pela consulta periódica, pelo webhook do provedor e pelo endpoint de simulação.
 *
 * <p>Nenhuma chamada ao provedor acontece dentro de transação de banco: as transações são
 * abertas explicitamente, só em volta das escritas.
 */
@Service
public class PagamentoService {

    private static final Logger log = LoggerFactory.getLogger(PagamentoService.class);

    public enum ResultadoConfirmacao {
        CONFIRMADO,
        JA_PROCESSADO,
        DESCONHECIDO,
        VALOR_DIVERGENTE,
        TARDIO_RECONFIRMADO,
        TARDIO_ESTORNO_MANUAL
    }

    private final PagamentoRepository pagamentos;
    private final ReservaRepository reservas;
    private final PixGateway gateway;
    private final ReconfirmacaoTardiaService reconfirmacao;
    private final TransactionTemplate transacao;
    private final Clock relogio;

    public PagamentoService(PagamentoRepository pagamentos, ReservaRepository reservas, PixGateway gateway,
            ReconfirmacaoTardiaService reconfirmacao, PlatformTransactionManager transactionManager, Clock relogio) {
        this.pagamentos = pagamentos;
        this.reservas = reservas;
        this.gateway = gateway;
        this.reconfirmacao = reconfirmacao;
        this.transacao = new TransactionTemplate(transactionManager);
        this.relogio = relogio;
    }

    // ------------------------------------------------------------------ criação

    /**
     * Cria a cobrança no provedor (fora de transação) e persiste o pagamento com a mesma expiração
     * da reserva.
     *
     * @throws IntegracaoExternaException quando o provedor falha
     */
    public Pagamento criarCobranca(Long reservaId, BigDecimal valor, Instant expiraEm) {
        String txid = UUID.randomUUID().toString().replace("-", "");
        int segundos = (int) Math.max(1, Duration.between(relogio.instant(), expiraEm).toSeconds());
        CobrancaPix cobranca = gateway.criarCobranca(txid, valor, segundos, "Reserva " + reservaId);
        return transacao.execute(status -> {
            Pagamento p = new Pagamento();
            p.setReserva(reservas.getReferenceById(reservaId));
            p.setTxid(txid);
            p.setProvedor(gateway.provedor());
            p.setValor(valor);
            p.setStatus(StatusPagamento.PENDENTE);
            p.setPixCopiaECola(cobranca.pixCopiaECola());
            p.setLocation(cobranca.location());
            p.setExpiraEm(expiraEm);
            return pagamentos.saveAndFlush(p);
        });
    }

    /** Remoção da cobrança no provedor em regime de melhor esforço (RN13): falha só vai para o log. */
    public void removerNoProvedor(String txid) {
        try {
            gateway.removerCobranca(txid);
        } catch (RuntimeException e) {
            log.warn("Falha ao remover a cobrança {} no provedor: {}", txid, e.getMessage());
        }
    }

    // ------------------------------------------------------------------ confirmação

    /**
     * Ponto único de confirmação, idempotente. Zero linhas afetadas não significa "já processado":
     * o status é relido do banco para distinguir a corrida entre caminhos do pagamento tardio.
     */
    public ResultadoConfirmacao confirmar(String txid, String endToEndId, BigDecimal valorRecebido, Instant pagoEm) {
        try {
            return transacao.execute(status -> confirmarNaTransacao(txid, endToEndId, valorRecebido, pagoEm));
        } catch (DataIntegrityViolationException e) {
            if (ViolacaoDeIntegridade.foi(e, ViolacaoDeIntegridade.UX_PAGAMENTO_END_TO_END)) {
                log.warn("Identificador fim a fim {} já usado em outra cobrança; txid {} tratado como já processado",
                        endToEndId, txid);
                return ResultadoConfirmacao.JA_PROCESSADO;
            }
            throw e;
        }
    }

    private ResultadoConfirmacao confirmarNaTransacao(String txid, String endToEndId, BigDecimal valorRecebido,
            Instant pagoEm) {
        Optional<Pagamento> encontrado = pagamentos.buscarPorTxid(txid);
        if (encontrado.isEmpty()) {
            log.info("Confirmação para txid desconhecido {} ignorada", txid);
            return ResultadoConfirmacao.DESCONHECIDO;
        }
        // Lidos antes dos UPDATEs: depois deles a entidade fica desanexada e desatualizada (D4).
        Pagamento pagamento = encontrado.get();
        Long reservaId = pagamento.getReserva().getId();
        BigDecimal valorCobrado = pagamento.getValor();
        if (valorRecebido == null || valorRecebido.compareTo(valorCobrado) != 0) {
            log.warn("Valor divergente no txid {}: cobrado {}, recebido {}. Tratamento manual necessário.",
                    txid, valorCobrado, valorRecebido);
            return ResultadoConfirmacao.VALOR_DIVERGENTE;
        }
        Instant agora = relogio.instant();
        if (pagamentos.marcarPago(txid, endToEndId, pagoEm, agora) == 1) {
            if (reservas.transicionar(reservaId, StatusReserva.PENDENTE_PAGAMENTO, StatusReserva.CONFIRMADA,
                    agora) == 1) {
                log.info("Pagamento {} confirmado; reserva {} CONFIRMADA", txid, reservaId);
                return ResultadoConfirmacao.CONFIRMADO;
            }
            // Cobrança estava pendente mas a reserva não: trata como tardio para a reserva.
            return tratarReservaNaoPendente(txid, reservaId, valorCobrado);
        }
        StatusPagamento atual = pagamentos.lerStatus(txid).orElseThrow();
        return switch (atual) {
            case PAGO -> {
                log.info("Pagamento {} já estava PAGO; confirmação sem efeito", txid);
                yield ResultadoConfirmacao.JA_PROCESSADO;
            }
            case EXPIRADO, CANCELADO -> pagamentoTardio(txid, endToEndId, pagoEm, reservaId, valorCobrado);
            case PENDENTE -> throw new IllegalStateException("Cobrança " + txid + " pendente não foi atualizada");
        };
    }

    /**
     * RN14: primeiro tenta reconfirmar a reserva expirada (transação própria), depois marca a
     * cobrança como paga, porque o dinheiro entrou.
     */
    private ResultadoConfirmacao pagamentoTardio(String txid, String endToEndId, Instant pagoEm, Long reservaId,
            BigDecimal valor) {
        boolean reconfirmada = tentarReconfirmar(reservaId);
        if (pagamentos.marcarPagoTardio(txid, endToEndId, pagoEm, relogio.instant()) == 0) {
            log.info("Pagamento tardio {} já processado por outro caminho", txid);
            return ResultadoConfirmacao.JA_PROCESSADO;
        }
        return registrarTardio(txid, reservaId, valor, reconfirmada);
    }

    private ResultadoConfirmacao tratarReservaNaoPendente(String txid, Long reservaId, BigDecimal valor) {
        return registrarTardio(txid, reservaId, valor, tentarReconfirmar(reservaId));
    }

    private boolean tentarReconfirmar(Long reservaId) {
        if (reservas.lerStatus(reservaId).orElse(null) != StatusReserva.EXPIRADA) {
            return false;
        }
        try {
            return reconfirmacao.reconfirmar(reservaId);
        } catch (DataIntegrityViolationException e) {
            if (ViolacaoDeIntegridade.foi(e, ViolacaoDeIntegridade.UX_RESERVA_SLOT_ATIVO)) {
                return false; // slot já tomado por outro cliente
            }
            throw e;
        }
    }

    private static ResultadoConfirmacao registrarTardio(String txid, Long reservaId, BigDecimal valor,
            boolean reconfirmada) {
        if (reconfirmada) {
            log.info("Pagamento tardio {}: reserva {} reconfirmada (valor {})", txid, reservaId, valor);
            return ResultadoConfirmacao.TARDIO_RECONFIRMADO;
        }
        log.warn("ESTORNO MANUAL NECESSÁRIO: pagamento tardio txid={} reserva={} valor={}", txid, reservaId, valor);
        return ResultadoConfirmacao.TARDIO_ESTORNO_MANUAL;
    }

    // ------------------------------------------------------------------ consulta e simulação

    /** Estado da cobrança para o polling do cliente dono da reserva (RF20). */
    public Pagamento estado(Long reservaId, UsuarioAutenticado usuario) {
        Reserva reserva = reservas.findDetalhadaById(reservaId)
                .orElseThrow(() -> Excecoes.naoEncontrado("Reserva não encontrada."));
        if (!reserva.getCliente().getId().equals(usuario.id())) {
            throw Excecoes.acessoNegado();
        }
        return pagamentos.findByReservaId(reservaId)
                .orElseThrow(() -> Excecoes.naoEncontrado("Esta reserva não tem cobrança."));
    }

    /**
     * Simulação de pagamento (RF21). A propriedade é verificada antes de qualquer efeito. No
     * ambiente simulado confirma direto; nos demais pede ao provedor e deixa a detecção normal
     * confirmar.
     */
    public Pagamento simular(String txid, UsuarioAutenticado usuario) {
        Pagamento pagamento = pagamentos.buscarPorTxid(txid)
                .orElseThrow(() -> Excecoes.naoEncontrado("Cobrança não encontrada."));
        if (!pagamento.getReserva().getCliente().getId().equals(usuario.id())) {
            throw Excecoes.acessoNegado();
        }
        if (gateway.provedor() == ProvedorPagamento.SIMULADO) {
            String endToEndId = "SIM" + UUID.randomUUID().toString().replace("-", "").substring(0, 29);
            ResultadoConfirmacao resultado = confirmar(txid, endToEndId, pagamento.getValor(), relogio.instant());
            if (resultado == ResultadoConfirmacao.JA_PROCESSADO) {
                throw Excecoes.regra(SubcodigoErro.TRANSICAO_INVALIDA, "Esta cobrança já foi paga.");
            }
        } else {
            try {
                gateway.simularPagamento(txid, pagamento.getValor());
            } catch (IntegracaoExternaException e) {
                log.warn("Falha ao simular pagamento {} no provedor: {}", txid, e.getMessage());
                throw Excecoes.pagamentoIndisponivel();
            }
        }
        return pagamentos.buscarPorTxid(txid).orElseThrow();
    }

    /** Cobranças pendentes e no prazo para um ciclo do job de consulta. */
    public List<String> pendentesParaConsulta(int limite) {
        return pagamentos.buscarTxidsPendentes(relogio.instant(), PageRequest.of(0, limite));
    }

    /**
     * Usado pelo job de consulta: chama o provedor fora de transação e confirma se já pago.
     * Cobrança removida não muda nada no banco: a reserva expira normalmente (design.md D10).
     */
    public void sincronizarComProvedor(String txid) {
        PixGateway.StatusCobranca status = gateway.consultar(txid);
        switch (status.situacao()) {
            case CONCLUIDA -> confirmar(txid, status.endToEndId(), status.valorPago(),
                    status.pagoEm() != null ? status.pagoEm() : relogio.instant());
            case REMOVIDA_PELO_PSP, REMOVIDA_PELO_RECEBEDOR ->
                    log.info("Cobrança {} removida no provedor ({}); status local inalterado", txid, status.situacao());
            case ATIVA -> { }
        }
    }
}
