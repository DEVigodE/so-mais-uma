package br.com.puc.so_mais_uma.repository;

import br.com.puc.so_mais_uma.entity.Pagamento;
import br.com.puc.so_mais_uma.entity.StatusPagamento;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

/** Transições da cobrança por {@code UPDATE} condicional, como em {@link ReservaRepository}. */
public interface PagamentoRepository extends JpaRepository<Pagamento, Long> {

    @Query("SELECT p FROM Pagamento p JOIN FETCH p.reserva r JOIN FETCH r.cliente WHERE p.txid = :txid")
    Optional<Pagamento> buscarPorTxid(@Param("txid") String txid);

    Optional<Pagamento> findByReservaId(Long reservaId);

    @Query("SELECT p.status FROM Pagamento p WHERE p.txid = :txid")
    Optional<StatusPagamento> lerStatus(@Param("txid") String txid);

    /** Cobranças pendentes ainda no prazo, das mais antigas para as mais novas (job de consulta). */
    @Query("""
            SELECT p.txid FROM Pagamento p
            WHERE p.status = br.com.puc.so_mais_uma.entity.StatusPagamento.PENDENTE AND p.expiraEm > :agora
            ORDER BY p.criadoEm""")
    List<String> buscarTxidsPendentes(@Param("agora") Instant agora, Pageable limite);

    /** {@code PENDENTE -> PAGO}: caminho normal de confirmação. */
    @Transactional
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            UPDATE Pagamento p SET p.status = br.com.puc.so_mais_uma.entity.StatusPagamento.PAGO,
                p.endToEndId = :endToEndId, p.pagoEm = :pagoEm, p.atualizadoEm = :agora
            WHERE p.txid = :txid AND p.status = br.com.puc.so_mais_uma.entity.StatusPagamento.PENDENTE""")
    int marcarPago(@Param("txid") String txid, @Param("endToEndId") String endToEndId,
            @Param("pagoEm") Instant pagoEm, @Param("agora") Instant agora);

    /** {@code EXPIRADO|CANCELADO -> PAGO}: apenas no pagamento tardio (RN14). */
    @Transactional
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            UPDATE Pagamento p SET p.status = br.com.puc.so_mais_uma.entity.StatusPagamento.PAGO,
                p.endToEndId = :endToEndId, p.pagoEm = :pagoEm, p.atualizadoEm = :agora
            WHERE p.txid = :txid AND p.endToEndId IS NULL
              AND p.status IN (br.com.puc.so_mais_uma.entity.StatusPagamento.EXPIRADO,
                               br.com.puc.so_mais_uma.entity.StatusPagamento.CANCELADO)""")
    int marcarPagoTardio(@Param("txid") String txid, @Param("endToEndId") String endToEndId,
            @Param("pagoEm") Instant pagoEm, @Param("agora") Instant agora);

    @Transactional
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            UPDATE Pagamento p SET p.status = br.com.puc.so_mais_uma.entity.StatusPagamento.CANCELADO,
                p.atualizadoEm = :agora
            WHERE p.reserva.id = :reservaId AND p.status = br.com.puc.so_mais_uma.entity.StatusPagamento.PENDENTE""")
    int cancelarDaReserva(@Param("reservaId") Long reservaId, @Param("agora") Instant agora);

    @Transactional
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            UPDATE Pagamento p SET p.status = br.com.puc.so_mais_uma.entity.StatusPagamento.EXPIRADO,
                p.atualizadoEm = :agora
            WHERE p.status = br.com.puc.so_mais_uma.entity.StatusPagamento.PENDENTE AND p.expiraEm < :agora""")
    int expirarVencidos(@Param("agora") Instant agora);
}
