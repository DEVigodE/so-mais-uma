package br.com.puc.so_mais_uma.config;

import br.com.puc.so_mais_uma.integracao.cep.CepClient;
import java.net.http.HttpClient;
import java.time.Duration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

/** Clientes HTTP das fontes de CEP, com limite de tempo curto de conexão e de leitura (RNF04). */
@Configuration
public class CepConfig {

    @Bean
    public CepClient cepClient(RestClient.Builder builder, AppProperties props) {
        AppProperties.Cep cep = props.cep();
        JdkClientHttpRequestFactory fabrica = fabrica(cep.connectTimeout(), cep.readTimeout());
        return new CepClient(
                builder.clone().requestFactory(fabrica).baseUrl(cep.brasilapiUrl()).build(),
                builder.clone().requestFactory(fabrica).baseUrl(cep.viacepUrl()).build());
    }

    static JdkClientHttpRequestFactory fabrica(Duration conexao, Duration leitura) {
        HttpClient http = HttpClient.newBuilder().connectTimeout(conexao).build();
        JdkClientHttpRequestFactory fabrica = new JdkClientHttpRequestFactory(http);
        fabrica.setReadTimeout(leitura);
        return fabrica;
    }
}
