package br.com.puc.so_mais_uma.repository;

import br.com.puc.so_mais_uma.entity.Quadra;
import br.com.puc.so_mais_uma.entity.TipoEsporte;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface QuadraRepository extends JpaRepository<Quadra, Long> {

    List<Quadra> findByAtivaTrueOrderByNomeAsc();

    List<Quadra> findByAtivaTrueAndTipoEsporteOrderByNomeAsc(TipoEsporte tipoEsporte);

    List<Quadra> findByDonoIdOrderByNomeAsc(Long donoId);
}
