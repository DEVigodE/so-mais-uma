package br.com.puc.so_mais_uma.service;

import br.com.puc.so_mais_uma.dto.AuthDtos.LoginRequest;
import br.com.puc.so_mais_uma.dto.AuthDtos.RegistrarRequest;
import br.com.puc.so_mais_uma.dto.AuthDtos.TokenResponse;
import br.com.puc.so_mais_uma.dto.Datas;
import br.com.puc.so_mais_uma.dto.UsuarioResponse;
import br.com.puc.so_mais_uma.entity.Usuario;
import br.com.puc.so_mais_uma.exception.ApiException;
import br.com.puc.so_mais_uma.exception.CodigoErro;
import br.com.puc.so_mais_uma.exception.ViolacaoDeIntegridade;
import br.com.puc.so_mais_uma.repository.UsuarioRepository;
import br.com.puc.so_mais_uma.security.JwtService;
import br.com.puc.so_mais_uma.security.LoginBloqueioService;
import java.util.Locale;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Cadastro com auto-login e login por e-mail e senha (RF01, RF02, RF04, RN20). */
@Service
public class AuthService {

    private final UsuarioRepository usuarios;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final LoginBloqueioService bloqueio;
    /** Compara mesmo quando o e-mail não existe, para não revelar isso pelo tempo de resposta. */
    private final String hashFicticio;

    public AuthService(UsuarioRepository usuarios, PasswordEncoder passwordEncoder, JwtService jwtService,
            LoginBloqueioService bloqueio) {
        this.usuarios = usuarios;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.bloqueio = bloqueio;
        this.hashFicticio = passwordEncoder.encode("senha-ficticia-1");
    }

    @Transactional
    public TokenResponse registrar(RegistrarRequest req) {
        Usuario usuario = new Usuario();
        usuario.setNome(req.nome().trim());
        usuario.setEmail(normalizarEmail(req.email()));
        usuario.setSenhaHash(passwordEncoder.encode(req.senha()));
        usuario.setTelefone(vazioParaNulo(req.telefone()));
        usuario.setPerfil(req.perfil());
        try {
            usuarios.saveAndFlush(usuario);
        } catch (DataIntegrityViolationException e) {
            if (ViolacaoDeIntegridade.foi(e, ViolacaoDeIntegridade.UX_USUARIO_EMAIL)) {
                throw new ApiException(CodigoErro.EMAIL_JA_CADASTRADO, "Este e-mail já está cadastrado.");
            }
            throw e;
        }
        return token(usuario);
    }

    public TokenResponse login(LoginRequest req) {
        String email = normalizarEmail(req.email());
        bloqueio.verificar(email);
        Usuario usuario = usuarios.findByEmail(email).filter(Usuario::isAtivo).orElse(null);
        String hash = usuario != null ? usuario.getSenhaHash() : hashFicticio;
        boolean confere = passwordEncoder.matches(req.senha(), hash);
        if (usuario == null || !confere) {
            bloqueio.registrarFalha(email);
            throw new ApiException(CodigoErro.CREDENCIAL_INVALIDA, "E-mail ou senha incorretos.");
        }
        bloqueio.registrarSucesso(email);
        return token(usuario);
    }

    private TokenResponse token(Usuario usuario) {
        JwtService.TokenEmitido emitido = jwtService.emitir(usuario);
        return new TokenResponse(emitido.token(), Datas.instante(emitido.expiraEm()), UsuarioResponse.de(usuario));
    }

    static String normalizarEmail(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }

    static String vazioParaNulo(String valor) {
        return valor == null || valor.isBlank() ? null : valor.trim();
    }
}
