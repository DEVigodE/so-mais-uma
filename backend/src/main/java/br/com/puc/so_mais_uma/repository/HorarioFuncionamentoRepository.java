package br.com.puc.so_mais_uma.repository;

import br.com.puc.so_mais_uma.entity.HorarioFuncionamento;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface HorarioFuncionamentoRepository extends JpaRepository<HorarioFuncionamento, Long> {

    List<HorarioFuncionamento> findByQuadraIdOrderByDiaSemanaAsc(Long quadraId);

    Optional<HorarioFuncionamento> findByQuadraIdAndDiaSemana(Long quadraId, Integer diaSemana);

    Optional<HorarioFuncionamento> findByIdAndQuadraId(Long id, Long quadraId);
}
