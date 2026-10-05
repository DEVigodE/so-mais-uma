package br.com.puc.so_mais_uma;

import br.com.puc.so_mais_uma.entity.HorarioFuncionamento;
import br.com.puc.so_mais_uma.entity.PerfilUsuario;
import br.com.puc.so_mais_uma.entity.Quadra;
import br.com.puc.so_mais_uma.entity.Reserva;
import br.com.puc.so_mais_uma.entity.StatusReserva;
import br.com.puc.so_mais_uma.entity.TipoEsporte;
import br.com.puc.so_mais_uma.entity.Usuario;
import br.com.puc.so_mais_uma.repository.HorarioFuncionamentoRepository;
import br.com.puc.so_mais_uma.repository.QuadraRepository;
import br.com.puc.so_mais_uma.repository.ReservaRepository;
import br.com.puc.so_mais_uma.repository.UsuarioRepository;
import br.com.puc.so_mais_uma.security.UsuarioAutenticado;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.postgresql.PostgreSQLContainer;

/**
 * Base dos testes de integração: um único contêiner {@code postgres:18-alpine} por execução,
 * conectado automaticamente ao datasource da aplicação, mais atalhos para montar dados.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("simulado")
public abstract class IntegracaoTestBase {

    protected static final ZoneId SAO_PAULO = ZoneId.of("America/Sao_Paulo");

    @ServiceConnection
    protected static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:18-alpine");

    static {
        POSTGRES.start();
    }

    @Autowired
    protected UsuarioRepository usuarioRepository;

    @Autowired
    protected QuadraRepository quadraRepository;

    @Autowired
    protected HorarioFuncionamentoRepository horarioRepository;

    @Autowired
    protected ReservaRepository reservaRepository;

    protected Usuario novoUsuario(PerfilUsuario perfil) {
        Usuario u = new Usuario();
        u.setNome(perfil == PerfilUsuario.DONO ? "Dono Teste" : "Cliente Teste");
        u.setEmail(perfil.name().toLowerCase() + "-" + UUID.randomUUID() + "@teste.com");
        u.setSenhaHash("$2a$10$abcdefghijklmnopqrstuuDlC6mXg0l5bEj2q0x5a8b9c1d2e3f4g");
        u.setTelefone("31999990000");
        u.setPerfil(perfil);
        return usuarioRepository.saveAndFlush(u);
    }

    protected Quadra novaQuadra(Usuario dono) {
        Quadra q = new Quadra();
        q.setDono(dono);
        q.setNome("Quadra " + UUID.randomUUID().toString().substring(0, 8));
        q.setTipoEsporte(TipoEsporte.FUTSAL);
        q.setPrecoHora(new BigDecimal("80.00"));
        q.setCep("30130000");
        q.setLogradouro("Rua Teste");
        q.setNumero("100");
        q.setCidade("Belo Horizonte");
        q.setUf("MG");
        return quadraRepository.saveAndFlush(q);
    }

    /** Faixa de funcionamento em todos os sete dias. */
    protected void abrirTodosOsDias(Quadra quadra, int abertura, int fechamento) {
        for (int dia = 1; dia <= 7; dia++) {
            HorarioFuncionamento h = new HorarioFuncionamento();
            h.setQuadra(quadra);
            h.setDiaSemana(dia);
            h.setHoraAbertura(LocalTime.of(abertura, 0));
            h.setHoraFechamento(LocalTime.of(fechamento, 0));
            horarioRepository.saveAndFlush(h);
        }
    }

    /** Insere uma reserva diretamente no status pedido (sem passar pelas regras). */
    protected Reserva novaReserva(Quadra quadra, Usuario cliente, Instant inicio, StatusReserva status) {
        Reserva r = new Reserva();
        r.setQuadra(quadra);
        r.setCliente(cliente);
        r.setInicio(inicio);
        r.setFim(inicio.plus(1, ChronoUnit.HOURS));
        r.setValor(quadra.getPrecoHora());
        r.setStatus(status);
        r.setExpiraEm(Instant.now().plus(15, ChronoUnit.MINUTES));
        if (status == StatusReserva.CANCELADA) {
            r.setCanceladoPor(br.com.puc.so_mais_uma.entity.CanceladoPor.CLIENTE);
            r.setCanceladoEm(Instant.now());
        }
        return reservaRepository.saveAndFlush(r);
    }

    /** Hora cheia local em {@code dias} a partir de hoje. */
    protected static Instant horaLocal(int dias, int hora) {
        return ZonedDateTime.now(SAO_PAULO).truncatedTo(ChronoUnit.DAYS).plusDays(dias).withHour(hora).toInstant();
    }

    protected static UsuarioAutenticado autenticado(Usuario u) {
        return new UsuarioAutenticado(u.getId(), u.getPerfil(), u.getNome());
    }
}
