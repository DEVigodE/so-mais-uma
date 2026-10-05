package br.com.puc.so_mais_uma.dto;

/** Política de senha (RF01, RF05): 8 a 72 caracteres com ao menos uma letra e um número. */
public final class Senhas {

    /** 72 é o limite de bytes do BCrypt. */
    public static final String POLITICA = "^(?=.*[A-Za-z])(?=.*\\d).{8,72}$";
    public static final String MENSAGEM = "deve ter no mínimo 8 caracteres, com letra e número";

    private Senhas() {}
}
