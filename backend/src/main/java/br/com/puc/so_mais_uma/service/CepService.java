package br.com.puc.so_mais_uma.service;

import br.com.puc.so_mais_uma.exception.ApiException;
import br.com.puc.so_mais_uma.exception.CodigoErro;
import br.com.puc.so_mais_uma.exception.Excecoes;
import br.com.puc.so_mais_uma.exception.IntegracaoExternaException;
import br.com.puc.so_mais_uma.integracao.cep.CepClient;
import br.com.puc.so_mais_uma.integracao.cep.CepClient.EnderecoCep;
import org.springframework.stereotype.Service;

/** Consulta de CEP sempre pelo backend (RF09). O formato já foi validado no controller. */
@Service
public class CepService {

    private final CepClient cepClient;

    public CepService(CepClient cepClient) {
        this.cepClient = cepClient;
    }

    public EnderecoCep consultar(String cep) {
        try {
            return cepClient.consultar(cep).orElseThrow(() -> Excecoes.naoEncontrado("CEP não encontrado."));
        } catch (IntegracaoExternaException e) {
            throw new ApiException(CodigoErro.CEP_INDISPONIVEL,
                    "Não foi possível consultar o CEP agora. Preencha o endereço manualmente.");
        }
    }
}
