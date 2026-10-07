package br.com.puc.so_mais_uma.support;

import br.com.puc.so_mais_uma.config.AppProperties;
import br.com.puc.so_mais_uma.entity.PerfilUsuario;
import br.com.puc.so_mais_uma.entity.Usuario;
import java.time.Duration;
import java.time.ZoneId;
import org.springframework.test.util.ReflectionTestUtils;

/** Objetos de domínio e configuração prontos para testes de unidade. */
public final class Fixtures {

    public static final String SEGREDO_TESTE = "segredo-de-teste-com-mais-de-32-bytes-0123";

    private Fixtures() {}

    public static AppProperties props() {
        return props(SEGREDO_TESTE);
    }

    public static AppProperties props(String segredo) {
        return new AppProperties("/api/v1", ZoneId.of("America/Sao_Paulo"),
                new AppProperties.Jwt(segredo, Duration.ofDays(7)),
                new AppProperties.Reserva(Duration.ofMinutes(15), 14),
                new AppProperties.Login(5, Duration.ofMinutes(15)),
                new AppProperties.Cep("http://localhost", "http://localhost", Duration.ofSeconds(1), Duration.ofSeconds(1)),
                new AppProperties.Dev(true, "dev-key-teste"),
                new AppProperties.Pix(false, false,
                        new AppProperties.Simulado("somaisuma@exemplo.com", "SO MAIS UMA", "BELO HORIZONTE"), null));
    }

    public static Usuario usuario(long id, PerfilUsuario perfil) {
        Usuario u = new Usuario();
        u.setId(id);
        u.setNome(perfil == PerfilUsuario.DONO ? "Dono " + id : "Cliente " + id);
        u.setEmail((perfil == PerfilUsuario.DONO ? "dono" : "cliente") + id + "@teste.com");
        u.setSenhaHash("hash");
        u.setPerfil(perfil);
        return u;
    }

    /** Define um campo sem setter (ex.: auditoria preenchida pelo Hibernate). */
    public static void campo(Object alvo, String nome, Object valor) {
        ReflectionTestUtils.setField(alvo, nome, valor);
    }
}
