package br.com.puc.so_mais_uma.config;

import br.com.puc.so_mais_uma.integracao.pix.inter.InterPixGateway;
import br.com.puc.so_mais_uma.integracao.pix.inter.InterTokenService;
import java.net.http.HttpClient;
import java.time.Clock;
import java.time.Duration;
import org.springframework.boot.ssl.SslBundles;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

/**
 * Cliente do Banco Inter nos ambientes integrados: mTLS pelo bundle PEM {@code inter}, conexão
 * de 5 s e leitura de 10 s, um único {@link RestClient} com a URL base do ambiente.
 */
@Configuration
@Profile({"inter-sandbox", "inter-prod"})
public class InterConfig {

    static final Duration CONEXAO = Duration.ofSeconds(5);
    static final Duration LEITURA = Duration.ofSeconds(10);

    @Bean
    public RestClient interRestClient(RestClient.Builder builder, SslBundles bundles, AppProperties props) {
        HttpClient http = HttpClient.newBuilder()
                .connectTimeout(CONEXAO)
                .sslContext(bundles.getBundle("inter").createSslContext())
                .build();
        JdkClientHttpRequestFactory fabrica = new JdkClientHttpRequestFactory(http);
        fabrica.setReadTimeout(LEITURA);
        return builder.clone().requestFactory(fabrica).baseUrl(props.pix().inter().baseUrl()).build();
    }

    @Bean
    public InterTokenService interTokenService(RestClient interRestClient, AppProperties props, Clock relogio) {
        AppProperties.Inter inter = props.pix().inter();
        return new InterTokenService(interRestClient, inter.clientId(), inter.clientSecret(), inter.escopos(), relogio);
    }

    @Bean
    public InterPixGateway interPixGateway(RestClient interRestClient, InterTokenService tokens, AppProperties props) {
        return new InterPixGateway(interRestClient, tokens, props.pix().inter().chave());
    }
}
