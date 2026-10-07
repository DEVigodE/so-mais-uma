package br.com.puc.so_mais_uma.security;

import br.com.puc.so_mais_uma.entity.PerfilUsuario;

/** Portador do token da requisição atual, injetado nos controllers como parâmetro. */
public record UsuarioAutenticado(Long id, PerfilUsuario perfil, String nome) {

    public boolean isDono() {
        return perfil == PerfilUsuario.DONO;
    }

    public boolean isCliente() {
        return perfil == PerfilUsuario.CLIENTE;
    }
}
