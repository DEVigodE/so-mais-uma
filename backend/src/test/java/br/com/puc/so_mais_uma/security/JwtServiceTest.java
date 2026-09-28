package br.com.puc.so_mais_uma.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import br.com.puc.so_mais_uma.entity.PerfilUsuario;
import br.com.puc.so_mais_uma.support.Fixtures;
import br.com.puc.so_mais_uma.support.RelogioAjustavel;
import java.time.Duration;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtException;

class JwtServiceTest {

    private final RelogioAjustavel relogio = new RelogioAjustavel(Instant.parse("2026-10-10T12:00:00Z"));
    private final JwtService service = new JwtService(Fixtures.props(), relogio);

    @Test
    void tokenTrazSubPerfilNomeIatEExp() {
        JwtService.TokenEmitido emitido = service.emitir(Fixtures.usuario(42, PerfilUsuario.DONO));

        Jwt jwt = service.decoder().decode(emitido.token());
        assertThat(jwt.getSubject()).isEqualTo("42");
        assertThat(jwt.getClaimAsString("perfil")).isEqualTo("DONO");
        assertThat(jwt.getClaimAsString("nome")).isEqualTo("Dono 42");
        assertThat(jwt.getHeaders()).containsEntry("alg", "HS256");
        assertThat(jwt.getIssuedAt()).isEqualTo(relogio.instant());
    }

    @Test
    void expiraSeteDiasAposAEmissao() {
        JwtService.TokenEmitido emitido = service.emitir(Fixtures.usuario(1, PerfilUsuario.CLIENTE));

        Jwt jwt = service.decoder().decode(emitido.token());
        assertThat(Duration.between(jwt.getIssuedAt(), jwt.getExpiresAt())).isEqualTo(Duration.ofDays(7));
        assertThat(emitido.expiraEm()).isEqualTo(jwt.getExpiresAt());
    }

    @Test
    void tokenExpiradoERecusado() {
        String token = service.emitir(Fixtures.usuario(1, PerfilUsuario.CLIENTE)).token();
        relogio.avancar(Duration.ofDays(7).plusSeconds(1));

        assertThatThrownBy(() -> service.decoder().decode(token)).isInstanceOf(JwtException.class);
    }

    @Test
    void tokenAdulteradoERecusado() {
        String token = service.emitir(Fixtures.usuario(1, PerfilUsuario.CLIENTE)).token();
        String[] partes = token.split("\\.");
        String adulterado = partes[0] + "." + partes[1] + "." + new StringBuilder(partes[2]).reverse();

        assertThatThrownBy(() -> service.decoder().decode(adulterado)).isInstanceOf(JwtException.class);
    }

    @Test
    void tokenAssinadoComOutroSegredoERecusado() {
        JwtService outro = new JwtService(Fixtures.props("outro-segredo-tambem-com-mais-de-32-bytes!"), relogio);
        String token = outro.emitir(Fixtures.usuario(1, PerfilUsuario.CLIENTE)).token();

        assertThatThrownBy(() -> service.decoder().decode(token)).isInstanceOf(JwtException.class);
    }

    @Test
    void segredoCurtoImpedeASubida() {
        assertThatThrownBy(() -> new JwtService(Fixtures.props("curto-demais"), relogio))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("32 bytes");
    }
}
