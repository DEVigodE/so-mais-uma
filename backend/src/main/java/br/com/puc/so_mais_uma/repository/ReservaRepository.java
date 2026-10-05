package br.com.puc.so_mais_uma.repository;

import br.com.puc.so_mais_uma.entity.CanceladoPor;
import br.com.puc.so_mais_uma.entity.Reserva;
import br.com.puc.so_mais_uma.entity.StatusReserva;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

/**
 * Toda mudança de status é um {@code UPDATE ... WHERE status = <esperado>} cujo número de linhas
 * afetadas é o resultado (design.md D4). As consultas de modificação limpam o contexto de
 * persistência: entidades carregadas antes ficam desanexadas e com o status antigo, então quem
 * precisa do status depois deve relê-lo do banco.
 */
public interface ReservaRepository extends JpaRepository<Reserva, Long> {

    Optional<Reserva> findFirstByClienteIdAndStatus(Long clienteId, StatusReserva status);

    /** Reserva com quadra e cliente carregados, pronta para virar resposta. */
    @EntityGraph(attributePaths = {"quadra", "cliente"})
    Optional<Reserva> findDetalhadaById(Long id);

    @Query("""
            SELECT count(r) FROM Reserva r
            WHERE r.quadra.id = :quadraId AND r.status IN :ativos AND r.inicio > :agora""")
    long contarAtivasFuturas(@Param("quadraId") Long quadraId, @Param("ativos") Collection<StatusReserva> ativos,
            @Param("agora") Instant agora);

    @Query("""
            SELECT r FROM Reserva r
            WHERE r.quadra.id = :quadraId AND r.status IN :ativos AND r.inicio > :agora""")
    List<Reserva> buscarAtivasFuturas(@Param("quadraId") Long quadraId,
            @Param("ativos") Collection<StatusReserva> ativos, @Param("agora") Instant agora);

    @Query("""
            SELECT r.inicio FROM Reserva r
            WHERE r.quadra.id = :quadraId AND r.status IN :ativos AND r.inicio >= :de AND r.inicio < :ate""")
    List<Instant> buscarIniciosOcupados(@Param("quadraId") Long quadraId,
            @Param("ativos") Collection<StatusReserva> ativos, @Param("de") Instant de, @Param("ate") Instant ate);

    @Query("""
            SELECT r FROM Reserva r JOIN FETCH r.quadra q JOIN FETCH r.cliente
            WHERE r.cliente.id = :clienteId AND r.inicio >= :desde ORDER BY r.inicio""")
    List<Reserva> buscarDoCliente(@Param("clienteId") Long clienteId, @Param("desde") Instant desde);

    @Query("""
            SELECT r FROM Reserva r JOIN FETCH r.quadra q JOIN FETCH r.cliente
            WHERE q.dono.id = :donoId AND r.inicio >= :desde ORDER BY r.inicio""")
    List<Reserva> buscarDoDono(@Param("donoId") Long donoId, @Param("desde") Instant desde);

    @Query("""
            SELECT r FROM Reserva r JOIN FETCH r.cliente
            WHERE r.quadra.id = :quadraId AND r.inicio >= :de AND r.inicio < :ate ORDER BY r.inicio""")
    List<Reserva> buscarDaQuadraNoPeriodo(@Param("quadraId") Long quadraId, @Param("de") Instant de,
            @Param("ate") Instant ate);

    @Query("""
            SELECT r FROM Reserva r JOIN FETCH r.cliente
            WHERE r.quadra.id = :quadraId AND r.status IN :ativos AND r.fim > :agora ORDER BY r.inicio""")
    List<Reserva> buscarProximasDaQuadra(@Param("quadraId") Long quadraId,
            @Param("ativos") Collection<StatusReserva> ativos, @Param("agora") Instant agora);

    @Query("SELECT r.status FROM Reserva r WHERE r.id = :id")
    Optional<StatusReserva> lerStatus(@Param("id") Long id);

    @Transactional
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            UPDATE Reserva r SET r.status = :para, r.atualizadoEm = :agora
            WHERE r.id = :id AND r.status = :de""")
    int transicionar(@Param("id") Long id, @Param("de") StatusReserva de, @Param("para") StatusReserva para,
            @Param("agora") Instant agora);

    @Transactional
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            UPDATE Reserva r SET r.status = br.com.puc.so_mais_uma.entity.StatusReserva.CANCELADA,
                r.canceladoPor = :por, r.motivoCancelamento = :motivo, r.canceladoEm = :agora, r.atualizadoEm = :agora
            WHERE r.id = :id AND r.status = :esperado""")
    int cancelar(@Param("id") Long id, @Param("esperado") StatusReserva esperado, @Param("por") CanceladoPor por,
            @Param("motivo") String motivo, @Param("agora") Instant agora);

    @Transactional
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            UPDATE Reserva r SET r.status = br.com.puc.so_mais_uma.entity.StatusReserva.EXPIRADA, r.atualizadoEm = :agora
            WHERE r.status = br.com.puc.so_mais_uma.entity.StatusReserva.PENDENTE_PAGAMENTO AND r.expiraEm < :agora""")
    int expirarVencidas(@Param("agora") Instant agora);

    @Transactional
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            UPDATE Reserva r SET r.observacao = :observacao, r.atualizadoEm = :agora
            WHERE r.id = :id AND r.status IN :ativos""")
    int atualizarObservacao(@Param("id") Long id, @Param("observacao") String observacao,
            @Param("ativos") Collection<StatusReserva> ativos, @Param("agora") Instant agora);
}
