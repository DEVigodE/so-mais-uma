package br.com.puc.so_mais_uma.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.willThrow;
import static org.mockito.Mockito.mock;

import br.com.puc.so_mais_uma.dto.AuthDtos.AtualizarUsuarioRequest;
import br.com.puc.so_mais_uma.dto.AuthDtos.LoginRequest;
import br.com.puc.so_mais_uma.dto.AuthDtos.RegistrarRequest;
import br.com.puc.so_mais_uma.dto.AuthDtos.TokenResponse;
import br.com.puc.so_mais_uma.entity.PerfilUsuario;
import br.com.puc.so_mais_uma.entity.Usuario;
import br.com.puc.so_mais_uma.exception.ApiException;
import br.com.puc.so_mais_uma.exception.CodigoErro;
import br.com.puc.so_mais_uma.exception.RegraNegocioException;
import br.com.puc.so_mais_uma.exception.SubcodigoErro;
import br.com.puc.so_mais_uma.repository.UsuarioRepository;
import br.com.puc.so_mais_uma.security.JwtService;
import br.com.puc.so_mais_uma.security.LoginBloqueioService;
import br.com.puc.so_mais_uma.support.Fixtures;
import br.com.puc.so_mais_uma.support.RelogioAjustavel;
import java.sql.SQLException;
import java.time.Duration;
import java.time.Instant;
import java.util.Optional;
import org.hibernate.exception.ConstraintViolationException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

class AuthServiceTest {

    private final RelogioAjustavel relogio = new RelogioAjustavel(Instant.parse("2026-10-10T12:00:00Z"));
    private final PasswordEncoder encoder = new BCryptPasswordEncoder(4);
    private final UsuarioRepository usuarios = mock(UsuarioRepository.class);
    private final LoginBloqueioService bloqueio = new LoginBloqueioService(Fixtures.props(), relogio);
    private final JwtService jwt = new JwtService(Fixtures.props(), relogio);
    private final AuthService auth = new AuthService(usuarios, encoder, jwt, bloqueio);
    private final UsuarioService usuarioService = new UsuarioService(usuarios, encoder);

    private Usuario ana;

    @BeforeEach
    void setUp() {
        ana = Fixtures.usuario(1, PerfilUsuario.CLIENTE);
        ana.setEmail("ana@teste.com");
        ana.setSenhaHash(encoder.encode("Senha123"));
        given(usuarios.findByEmail("ana@teste.com")).willReturn(Optional.of(ana));
        given(usuarios.findById(1L)).willReturn(Optional.of(ana));
        given(usuarios.saveAndFlush(any())).willAnswer(inv -> {
            Usuario u = inv.getArgument(0);
            if (u.getId() == null) {
                u.setId(99L);
            }
            return u;
        });
    }

    // ---- cadastro

    @Test
    void cadastroNormalizaEmailGuardaHashEJaDevolveToken() {
        TokenResponse resposta = auth.registrar(
                new RegistrarRequest("Bia", "  Bia@Teste.COM ", "Senha123", "", PerfilUsuario.DONO));

        assertThat(resposta.usuario().email()).isEqualTo("bia@teste.com");
        assertThat(resposta.usuario().perfil()).isEqualTo(PerfilUsuario.DONO);
        assertThat(resposta.usuario().telefone()).isNull();
        assertThat(jwt.decoder().decode(resposta.token()).getClaimAsString("perfil")).isEqualTo("DONO");
    }

    @Test
    void emailDuplicadoVira409PeloNomeDaConstraint() {
        willThrow(violacao("ux_usuario_email")).given(usuarios).saveAndFlush(any());

        assertThatThrownBy(() -> auth.registrar(
                new RegistrarRequest("Bia", "ana@teste.com", "Senha123", null, PerfilUsuario.CLIENTE)))
                .isInstanceOfSatisfying(ApiException.class,
                        e -> assertThat(e.getCodigo()).isEqualTo(CodigoErro.EMAIL_JA_CADASTRADO));
    }

    @Test
    void outraViolacaoDeIntegridadeNaoViraEmailDuplicado() {
        willThrow(violacao("ck_usuario_perfil")).given(usuarios).saveAndFlush(any());

        assertThatThrownBy(() -> auth.registrar(
                new RegistrarRequest("Bia", "bia@teste.com", "Senha123", null, PerfilUsuario.CLIENTE)))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    // ---- login e bloqueio

    @Test
    void loginCorretoDevolveToken() {
        assertThat(auth.login(new LoginRequest("ANA@teste.com", "Senha123")).token()).isNotBlank();
    }

    @Test
    void emailInexistenteESenhaErradaSaoIndistinguiveis() {
        ApiException semConta = capturar(() -> auth.login(new LoginRequest("nao@existe.com", "Senha123")));
        ApiException senhaErrada = capturar(() -> auth.login(new LoginRequest("ana@teste.com", "Errada123")));

        assertThat(semConta.getCodigo()).isEqualTo(CodigoErro.CREDENCIAL_INVALIDA);
        assertThat(senhaErrada.getCodigo()).isEqualTo(CodigoErro.CREDENCIAL_INVALIDA);
        assertThat(semConta.getMessage()).isEqualTo(senhaErrada.getMessage());
    }

    @Test
    void sextaTentativaEBloqueadaMesmoComSenhaCorreta() {
        for (int i = 0; i < 5; i++) {
            assertThat(capturar(() -> auth.login(new LoginRequest("ana@teste.com", "Errada123"))).getCodigo())
                    .isEqualTo(CodigoErro.CREDENCIAL_INVALIDA);
        }

        ApiException bloqueado = capturar(() -> auth.login(new LoginRequest("ana@teste.com", "Senha123")));
        assertThat(bloqueado.getCodigo()).isEqualTo(CodigoErro.LOGIN_BLOQUEADO);
        assertThat(bloqueado.getMessage()).contains("15 minutos");
    }

    @Test
    void bloqueioExpiraDepoisDeQuinzeMinutos() {
        for (int i = 0; i < 5; i++) {
            capturar(() -> auth.login(new LoginRequest("ana@teste.com", "Errada123")));
        }
        relogio.avancar(Duration.ofMinutes(15));

        assertThat(auth.login(new LoginRequest("ana@teste.com", "Senha123")).token()).isNotBlank();
    }

    @Test
    void loginCorretoZeraOContador() {
        for (int i = 0; i < 3; i++) {
            capturar(() -> auth.login(new LoginRequest("ana@teste.com", "Errada123")));
        }
        auth.login(new LoginRequest("ana@teste.com", "Senha123"));
        for (int i = 0; i < 4; i++) {
            capturar(() -> auth.login(new LoginRequest("ana@teste.com", "Errada123")));
        }

        assertThat(auth.login(new LoginRequest("ana@teste.com", "Senha123")).token()).isNotBlank();
    }

    @Test
    void limpezaRemoveBloqueiosVencidos() {
        for (int i = 0; i < 5; i++) {
            capturar(() -> auth.login(new LoginRequest("ana@teste.com", "Errada123")));
        }
        relogio.avancar(Duration.ofMinutes(16));
        bloqueio.limparVencidos();

        // Depois da limpeza, uma falha isolada não bloqueia.
        capturar(() -> auth.login(new LoginRequest("ana@teste.com", "Errada123")));
        assertThat(auth.login(new LoginRequest("ana@teste.com", "Senha123")).token()).isNotBlank();
    }

    // ---- troca de senha

    @Test
    void trocaDeSenhaComSenhaAtualCorreta() {
        usuarioService.atualizar(1L, new AtualizarUsuarioRequest("Ana", "31999990000", "Senha123", "Nova12345"));

        assertThat(encoder.matches("Nova12345", ana.getSenhaHash())).isTrue();
        assertThat(capturar(() -> auth.login(new LoginRequest("ana@teste.com", "Senha123"))).getCodigo())
                .isEqualTo(CodigoErro.CREDENCIAL_INVALIDA);
        assertThat(auth.login(new LoginRequest("ana@teste.com", "Nova12345")).token()).isNotBlank();
    }

    @Test
    void senhaAtualIncorretaVira422EMantemASenha() {
        String hashAntes = ana.getSenhaHash();

        assertThatThrownBy(() -> usuarioService.atualizar(1L,
                new AtualizarUsuarioRequest("Ana", null, "Errada123", "Nova12345")))
                .isInstanceOfSatisfying(RegraNegocioException.class,
                        e -> assertThat(e.getSubcodigo()).isEqualTo(SubcodigoErro.SENHA_ATUAL_INCORRETA));
        assertThat(ana.getSenhaHash()).isEqualTo(hashAntes);
    }

    @Test
    void edicaoAlteraNomeETelefoneSemTocarEmailEPerfil() {
        Usuario atualizado = usuarioService.atualizar(1L, new AtualizarUsuarioRequest("Ana Maria", "3188887777", null, null));

        assertThat(atualizado.getNome()).isEqualTo("Ana Maria");
        assertThat(atualizado.getTelefone()).isEqualTo("3188887777");
        assertThat(atualizado.getEmail()).isEqualTo("ana@teste.com");
        assertThat(atualizado.getPerfil()).isEqualTo(PerfilUsuario.CLIENTE);
    }

    private static DataIntegrityViolationException violacao(String constraint) {
        return new DataIntegrityViolationException("violação",
                new ConstraintViolationException("violação", new SQLException("x"), constraint));
    }

    private static ApiException capturar(Runnable acao) {
        try {
            acao.run();
        } catch (ApiException e) {
            return e;
        }
        throw new AssertionError("era esperada uma ApiException");
    }
}
