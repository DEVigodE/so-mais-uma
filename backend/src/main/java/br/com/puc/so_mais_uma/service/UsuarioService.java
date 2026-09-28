package br.com.puc.so_mais_uma.service;

import br.com.puc.so_mais_uma.dto.AuthDtos.AtualizarUsuarioRequest;
import br.com.puc.so_mais_uma.entity.Usuario;
import br.com.puc.so_mais_uma.exception.ApiException;
import br.com.puc.so_mais_uma.exception.CodigoErro;
import br.com.puc.so_mais_uma.exception.Excecoes;
import br.com.puc.so_mais_uma.exception.SubcodigoErro;
import br.com.puc.so_mais_uma.repository.UsuarioRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Leitura e edição dos próprios dados (RF05). E-mail e perfil nunca mudam (RN20). */
@Service
public class UsuarioService {

    private final UsuarioRepository usuarios;
    private final PasswordEncoder passwordEncoder;

    public UsuarioService(UsuarioRepository usuarios, PasswordEncoder passwordEncoder) {
        this.usuarios = usuarios;
        this.passwordEncoder = passwordEncoder;
    }

    @Transactional(readOnly = true)
    public Usuario buscar(Long id) {
        return usuarios.findById(id).filter(Usuario::isAtivo)
                // Conta desativada com token ainda válido: tratada como sessão inválida.
                .orElseThrow(() -> new ApiException(CodigoErro.TOKEN_INVALIDO, "Sua sessão expirou. Entre novamente."));
    }

    @Transactional
    public Usuario atualizar(Long id, AtualizarUsuarioRequest req) {
        Usuario usuario = buscar(id);
        if (req.novaSenha() != null && !req.novaSenha().isEmpty()) {
            if (req.senhaAtual() == null || req.senhaAtual().isEmpty()) {
                throw Excecoes.validacao("senhaAtual", "é obrigatória para trocar a senha");
            }
            if (!passwordEncoder.matches(req.senhaAtual(), usuario.getSenhaHash())) {
                throw Excecoes.regra(SubcodigoErro.SENHA_ATUAL_INCORRETA, "A senha atual não confere.");
            }
            usuario.setSenhaHash(passwordEncoder.encode(req.novaSenha()));
        }
        usuario.setNome(req.nome().trim());
        usuario.setTelefone(AuthService.vazioParaNulo(req.telefone()));
        return usuarios.saveAndFlush(usuario);
    }
}
