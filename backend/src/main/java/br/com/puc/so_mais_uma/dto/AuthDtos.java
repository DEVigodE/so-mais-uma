package br.com.puc.so_mais_uma.dto;

import br.com.puc.so_mais_uma.entity.PerfilUsuario;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.OffsetDateTime;

/** DTOs de autenticação e perfil do usuário. */
public final class AuthDtos {

    private AuthDtos() {}

    public record RegistrarRequest(
            @NotBlank @Size(max = 100) String nome,
            @NotBlank @Email @Size(max = 150) String email,
            @NotNull @Pattern(regexp = Senhas.POLITICA, message = Senhas.MENSAGEM) String senha,
            @Size(max = 20) String telefone,
            @NotNull PerfilUsuario perfil) {}

    public record LoginRequest(@NotBlank @Email @Size(max = 150) String email, @NotBlank String senha) {}

    public record TokenResponse(String token, OffsetDateTime expiraEm, UsuarioResponse usuario) {}

    /** Nome e telefone sempre; senha apenas quando {@code novaSenha} vier preenchida. */
    public record AtualizarUsuarioRequest(
            @NotBlank @Size(max = 100) String nome,
            @Size(max = 20) String telefone,
            String senhaAtual,
            @Pattern(regexp = Senhas.POLITICA, message = Senhas.MENSAGEM) String novaSenha) {}
}
