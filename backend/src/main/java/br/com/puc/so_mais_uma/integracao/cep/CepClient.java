package br.com.puc.so_mais_uma.integracao.cep;

import br.com.puc.so_mais_uma.exception.IntegracaoExternaException;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClientResponseException;

/**
 * Consulta de CEP com fonte primária BrasilAPI CEP v2 e fallback ViaCEP (RF09). Cada fonte tem
 * limite de tempo curto; estourar o tempo conta como falha daquela fonte e aciona o fallback.
 */
public class CepClient {

    private static final Logger log = LoggerFactory.getLogger(CepClient.class);

    public enum Fonte { BRASILAPI, VIACEP }

    public record EnderecoCep(String cep, String logradouro, String bairro, String cidade, String uf,
            Double latitude, Double longitude, Fonte fonte) {}

    private final RestClient brasilApi;
    private final RestClient viaCep;

    public CepClient(RestClient brasilApi, RestClient viaCep) {
        this.brasilApi = brasilApi;
        this.viaCep = viaCep;
    }

    /**
     * @return o endereço, ou vazio quando o CEP não existe
     * @throws IntegracaoExternaException quando as duas fontes falham
     */
    public Optional<EnderecoCep> consultar(String cep) {
        Resultado primaria = tentar("BrasilAPI", () -> consultarBrasilApi(cep));
        if (primaria.endereco() != null) {
            return Optional.of(primaria.endereco());
        }
        Resultado secundaria = tentar("ViaCEP", () -> consultarViaCep(cep));
        if (secundaria.endereco() != null) {
            return Optional.of(secundaria.endereco());
        }
        if (primaria.naoEncontrado() || secundaria.naoEncontrado()) {
            return Optional.empty();
        }
        throw new IntegracaoExternaException("As duas fontes de CEP falharam");
    }

    private record Resultado(EnderecoCep endereco, boolean naoEncontrado) {}

    private interface Consulta {
        Optional<EnderecoCep> executar();
    }

    private static Resultado tentar(String nome, Consulta consulta) {
        try {
            return consulta.executar().map(e -> new Resultado(e, false)).orElseGet(() -> new Resultado(null, true));
        } catch (RestClientResponseException e) {
            if (e.getStatusCode().value() == 404) {
                return new Resultado(null, true);
            }
            log.warn("Fonte de CEP {} respondeu {}", nome, e.getStatusCode().value());
        } catch (RestClientException | IllegalStateException e) {
            log.warn("Fonte de CEP {} indisponível: {}", nome, e.getMessage());
        }
        return new Resultado(null, false);
    }

    private Optional<EnderecoCep> consultarBrasilApi(String cep) {
        BrasilApiCep r = brasilApi.get().uri("/api/cep/v2/{cep}", cep).retrieve()
                .body(BrasilApiCep.class);
        if (r == null || r.city() == null) {
            return Optional.empty();
        }
        Double lat = null;
        Double lon = null;
        if (r.location() != null && r.location().coordinates() != null) {
            lat = numero(r.location().coordinates().latitude());
            lon = numero(r.location().coordinates().longitude());
            if (lat == null || lon == null) {
                lat = null;
                lon = null;
            }
        }
        return Optional.of(new EnderecoCep(cep, r.street(), r.neighborhood(), r.city(), r.state(), lat, lon,
                Fonte.BRASILAPI));
    }

    private Optional<EnderecoCep> consultarViaCep(String cep) {
        ViaCep r = viaCep.get().uri("/ws/{cep}/json/", cep).retrieve()
                .body(ViaCep.class);
        if (r == null || "true".equalsIgnoreCase(String.valueOf(r.erro())) || r.localidade() == null) {
            return Optional.empty();
        }
        return Optional.of(new EnderecoCep(cep, vazio(r.logradouro()), vazio(r.bairro()), r.localidade(), r.uf(),
                null, null, Fonte.VIACEP));
    }

    private static Double numero(Object valor) {
        if (valor == null) {
            return null;
        }
        try {
            String texto = valor.toString().trim();
            return texto.isEmpty() ? null : Double.valueOf(texto);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private static String vazio(String valor) {
        return valor == null || valor.isBlank() ? null : valor;
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    record BrasilApiCep(String cep, String state, String city, String neighborhood, String street,
            Localizacao location) {}

    @JsonIgnoreProperties(ignoreUnknown = true)
    record Localizacao(Coordenadas coordinates) {}

    /** A BrasilAPI às vezes devolve as coordenadas como string, às vezes vazias. */
    @JsonIgnoreProperties(ignoreUnknown = true)
    record Coordenadas(Object latitude, Object longitude) {}

    @JsonIgnoreProperties(ignoreUnknown = true)
    record ViaCep(String cep, String logradouro, String bairro, String localidade, String uf, Object erro) {}
}
