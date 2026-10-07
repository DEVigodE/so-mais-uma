package br.com.puc.so_mais_uma.dto;

import br.com.puc.so_mais_uma.entity.PerfilUsuario;
import br.com.puc.so_mais_uma.entity.Usuario;
import java.time.OffsetDateTime;

/** Dados do usuário. Nunca contém a senha nem o seu hash. */
public record UsuarioResponse(Long id, String nome, String email, String telefone, PerfilUsuario perfil,
        OffsetDateTime criadoEm) {

    public static UsuarioResponse de(Usuario u) {
        return new UsuarioResponse(u.getId(), u.getNome(), u.getEmail(), u.getTelefone(), u.getPerfil(),
                Datas.instante(u.getCriadoEm()));
    }
}
