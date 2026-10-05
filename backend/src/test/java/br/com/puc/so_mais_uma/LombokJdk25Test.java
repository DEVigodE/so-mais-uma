package br.com.puc.so_mais_uma;

import static org.assertj.core.api.Assertions.assertThat;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.junit.jupiter.api.Test;

/** Prova que o processamento de anotações do Lombok funciona no JDK 25 (design.md, riscos). */
class LombokJdk25Test {

    @Getter
    @Setter
    @NoArgsConstructor
    static class Amostra {
        private String nome;
    }

    @Test
    void acessoresGeradosFuncionam() {
        Amostra amostra = new Amostra();
        amostra.setNome("quadra");
        assertThat(amostra.getNome()).isEqualTo("quadra");
    }
}
