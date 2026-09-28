package br.com.puc.so_mais_uma.security;

import br.com.puc.so_mais_uma.config.AppProperties;
import br.com.puc.so_mais_uma.entity.Usuario;
import com.nimbusds.jose.jwk.source.ImmutableSecret;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.JwtTimestampValidator;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.stereotype.Component;

/**
 * Emissão e leitura do token HS256 (design.md D12). O segredo vem do ambiente e precisa ter no
 * mínimo 32 bytes; caso contrário a aplicação não sobe.
 */
@Component
public class JwtService {

    public static final int TAMANHO_MINIMO_SEGREDO = 32;
    public static final String CLAIM_PERFIL = "perfil";
    public static final String CLAIM_NOME = "nome";

    private final JwtEncoder encoder;
    private final JwtDecoder decoder;
    private final Duration validade;
    private final Clock relogio;

    public JwtService(AppProperties props, Clock relogio) {
        String segredo = props.jwt() != null ? props.jwt().secret() : null;
        byte[] bytes = segredo == null ? new byte[0] : segredo.getBytes(StandardCharsets.UTF_8);
        if (bytes.length < TAMANHO_MINIMO_SEGREDO) {
            throw new IllegalStateException(
                    "JWT_SECRET precisa ter no mínimo " + TAMANHO_MINIMO_SEGREDO + " bytes");
        }
        SecretKey chave = new SecretKeySpec(bytes, "HmacSHA256");
        this.encoder = new NimbusJwtEncoder(new ImmutableSecret<>(chave));
        NimbusJwtDecoder nimbus = NimbusJwtDecoder.withSecretKey(chave).macAlgorithm(MacAlgorithm.HS256).build();
        JwtTimestampValidator validadorDeTempo = new JwtTimestampValidator(Duration.ZERO);
        validadorDeTempo.setClock(relogio);
        nimbus.setJwtValidator(validadorDeTempo);
        this.decoder = nimbus;
        this.validade = props.jwt().validade();
        this.relogio = relogio;
    }

    public record TokenEmitido(String token, Instant expiraEm) {}

    public TokenEmitido emitir(Usuario usuario) {
        Instant agora = relogio.instant();
        Instant expiraEm = agora.plus(validade);
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .subject(String.valueOf(usuario.getId()))
                .claim(CLAIM_PERFIL, usuario.getPerfil().name())
                .claim(CLAIM_NOME, usuario.getNome())
                .issuedAt(agora)
                .expiresAt(expiraEm)
                .build();
        JwsHeader header = JwsHeader.with(MacAlgorithm.HS256).build();
        String token = encoder.encode(JwtEncoderParameters.from(header, claims)).getTokenValue();
        return new TokenEmitido(token, expiraEm);
    }

    public JwtDecoder decoder() {
        return decoder;
    }
}
