package br.com.puc.so_mais_uma.service;

import br.com.puc.so_mais_uma.dto.QuadraDtos.QuadraRequest;
import br.com.puc.so_mais_uma.entity.Quadra;
import br.com.puc.so_mais_uma.entity.StatusReserva;
import br.com.puc.so_mais_uma.entity.TipoEsporte;
import br.com.puc.so_mais_uma.exception.CodigoErro;
import br.com.puc.so_mais_uma.exception.Excecoes;
import br.com.puc.so_mais_uma.repository.QuadraRepository;
import br.com.puc.so_mais_uma.repository.ReservaRepository;
import br.com.puc.so_mais_uma.repository.UsuarioRepository;
import br.com.puc.so_mais_uma.security.UsuarioAutenticado;
import java.math.BigDecimal;
import java.text.Normalizer;
import java.time.Clock;
import java.util.List;
import java.util.Locale;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** CRUD de quadras (RF06–RF08, RF10) com checagem de propriedade (RN01, RN03). */
@Service
public class QuadraService {

    private final QuadraRepository quadras;
    private final UsuarioRepository usuarios;
    private final ReservaRepository reservas;
    private final Clock relogio;

    public QuadraService(QuadraRepository quadras, UsuarioRepository usuarios, ReservaRepository reservas,
            Clock relogio) {
        this.quadras = quadras;
        this.usuarios = usuarios;
        this.reservas = reservas;
        this.relogio = relogio;
    }

    @Transactional
    public Quadra criar(Long donoId, QuadraRequest req) {
        Quadra quadra = new Quadra();
        quadra.setDono(usuarios.getReferenceById(donoId));
        aplicar(quadra, req);
        return quadras.saveAndFlush(quadra);
    }

    /** Quadras ativas, por nome, com filtros opcionais; cidade compara sem acento e sem caixa. */
    @Transactional(readOnly = true)
    public List<Quadra> listar(TipoEsporte esporte, String cidade) {
        List<Quadra> ativas = esporte == null ? quadras.findByAtivaTrueOrderByNomeAsc()
                : quadras.findByAtivaTrueAndTipoEsporteOrderByNomeAsc(esporte);
        if (cidade == null || cidade.isBlank()) {
            return ativas;
        }
        String alvo = normalizar(cidade);
        return ativas.stream().filter(q -> normalizar(q.getCidade()).equals(alvo)).toList();
    }

    @Transactional(readOnly = true)
    public List<Quadra> minhas(Long donoId) {
        return quadras.findByDonoIdOrderByNomeAsc(donoId);
    }

    /** Quadra visível ao usuário: inativa só é visível para o próprio dono (RN09). */
    @Transactional(readOnly = true)
    public Quadra buscarVisivel(Long id, UsuarioAutenticado usuario) {
        Quadra quadra = buscar(id);
        if (!quadra.isAtiva() && !quadra.pertenceA(usuario.id())) {
            throw naoEncontrada();
        }
        return quadra;
    }

    /** Quadra existente que pertence ao usuário; de outro dono responde 403, nunca 404 (RN03). */
    @Transactional(readOnly = true)
    public Quadra buscarDoDono(Long id, UsuarioAutenticado usuario) {
        Quadra quadra = buscar(id);
        if (!quadra.pertenceA(usuario.id())) {
            throw Excecoes.acessoNegado();
        }
        return quadra;
    }

    @Transactional(readOnly = true)
    public Quadra buscar(Long id) {
        return quadras.findById(id).orElseThrow(QuadraService::naoEncontrada);
    }

    @Transactional
    public Quadra atualizar(Long id, UsuarioAutenticado usuario, QuadraRequest req) {
        Quadra quadra = buscarDoDono(id, usuario);
        aplicar(quadra, req);
        return quadras.saveAndFlush(quadra);
    }

    /** Exclusão lógica, recusada enquanto houver reserva ativa futura (RN16). */
    @Transactional
    public void desativar(Long id, UsuarioAutenticado usuario) {
        Quadra quadra = buscarDoDono(id, usuario);
        long bloqueantes = reservas.contarAtivasFuturas(quadra.getId(), StatusReserva.ATIVOS, relogio.instant());
        if (bloqueantes > 0) {
            throw Excecoes.conflito(CodigoErro.QUADRA_COM_RESERVAS, bloqueantes == 1
                    ? "Existe 1 reserva ativa futura nesta quadra. Cancele-a antes de desativar."
                    : "Existem " + bloqueantes + " reservas ativas futuras nesta quadra. Cancele-as antes de desativar.");
        }
        quadra.setAtiva(false);
        quadras.saveAndFlush(quadra);
    }

    private static void aplicar(Quadra quadra, QuadraRequest req) {
        quadra.setNome(req.nome().trim());
        quadra.setTipoEsporte(req.tipoEsporte());
        quadra.setDescricao(AuthService.vazioParaNulo(req.descricao()));
        quadra.setPrecoHora(req.precoHora());
        quadra.setCep(req.cep());
        quadra.setLogradouro(req.logradouro().trim());
        quadra.setNumero(req.numero().trim());
        quadra.setBairro(AuthService.vazioParaNulo(req.bairro()));
        quadra.setCidade(req.cidade().trim());
        quadra.setUf(req.uf());
        quadra.setLatitude(req.latitude() == null ? null : BigDecimal.valueOf(req.latitude()));
        quadra.setLongitude(req.longitude() == null ? null : BigDecimal.valueOf(req.longitude()));
        quadra.setFotoUrl(AuthService.vazioParaNulo(req.fotoUrl()));
    }

    static String normalizar(String texto) {
        return Normalizer.normalize(texto.trim(), Normalizer.Form.NFD)
                .replaceAll("\\p{M}", "")
                .toLowerCase(Locale.ROOT);
    }

    static RuntimeException naoEncontrada() {
        return Excecoes.naoEncontrado("Quadra não encontrada.");
    }
}
