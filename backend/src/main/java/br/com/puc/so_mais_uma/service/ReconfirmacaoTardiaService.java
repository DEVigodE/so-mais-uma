package br.com.puc.so_mais_uma.service;

import br.com.puc.so_mais_uma.entity.StatusReserva;
import br.com.puc.so_mais_uma.repository.ReservaRepository;
import java.time.Clock;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Reconfirmação de reserva {@code EXPIRADA} por pagamento tardio (RN14), em transação própria e em
 * bean separado (design.md D6). A reconfirmação é a única operação do fluxo que pode violar
 * {@code ux_reserva_slot_ativo}; quando o PostgreSQL dispara a violação a transação em que o
 * comando rodou fica abortada, então ela precisa ser esta, e não a de quem chama. A violação não
 * é capturada aqui: sobe para quem chama, com esta transação já desfeita.
 */
@Service
public class ReconfirmacaoTardiaService {

    private final ReservaRepository reservas;
    private final Clock relogio;

    public ReconfirmacaoTardiaService(ReservaRepository reservas, Clock relogio) {
        this.reservas = reservas;
        this.relogio = relogio;
    }

    /** @return {@code true} se a reserva voltou a {@code CONFIRMADA} */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public boolean reconfirmar(Long reservaId) {
        return reservas.transicionar(reservaId, StatusReserva.EXPIRADA, StatusReserva.CONFIRMADA,
                relogio.instant()) == 1;
    }
}
