import 'package:so_mais_uma/src/imports/imports.dart';

import 'filtro_quadras.dart';

/// O que a lista de quadras mostra no momento (estado derivado, D4).
sealed class SituacaoQuadras {
  const SituacaoQuadras();
}

/// Primeira carga, ainda sem lista: esqueleto de 3 cards.
final class QuadrasCarregando extends SituacaoQuadras {
  const QuadrasCarregando();
}

/// Falha na primeira carga: caixa de erro com "Tentar novamente".
final class QuadrasErro extends SituacaoQuadras {
  const QuadrasErro(this.failure);
  final Failure failure;
}

/// `GET /quadras` devolveu lista vazia.
final class QuadrasCatalogoVazio extends SituacaoQuadras {
  const QuadrasCatalogoVazio();
}

/// Há catálogo, mas a busca e o esporte não acharam nada.
final class QuadrasSemResultado extends SituacaoQuadras {
  const QuadrasSemResultado();
}

final class QuadrasLista extends SituacaoQuadras {
  const QuadrasLista(this.quadras);
  final List<Quadra> quadras;
}

/// Aviso de uma única leitura (snackbar), consumido pelo contêiner.
final class AvisoQuadras {
  AvisoQuadras(this.mensagem);
  final String mensagem;
}

/// Store da tela Quadras (`/quadras`).
///
/// Busca o catálogo com uma chamada a `GET /quadras` e aplica a busca e o chip
/// de esporte localmente ([filtrarQuadras]). Com lista já carregada, uma
/// atualização que falha mantém a lista e vira [aviso].
class QuadrasStore {
  QuadrasStore(this._repositorio);

  final QuadraRepository _repositorio;

  final _catalogo = signal<RequestState<List<Quadra>>>(const RequestInitial());
  final _atualizando = signal(false);
  final _busca = signal('');
  final _esporte = signal<TipoEsporte?>(null);
  final _aviso = signal<AvisoQuadras?>(null);

  bool _descartado = false;
  int _geracao = 0;

  ReadonlySignal<RequestState<List<Quadra>>> get catalogo => _catalogo;

  /// Atualização em andamento com a lista já na tela (puxar para atualizar).
  ReadonlySignal<bool> get atualizando => _atualizando;
  ReadonlySignal<String> get busca => _busca;

  /// Esporte do chip selecionado; `null` = "Todos".
  ReadonlySignal<TipoEsporte?> get esporte => _esporte;
  ReadonlySignal<AvisoQuadras?> get aviso => _aviso;

  late final _temFiltro = computed(
    () => _busca.value.trim().isNotEmpty || _esporte.value != null,
  );

  /// Há busca ou esporte aplicados.
  ReadonlySignal<bool> get temFiltro => _temFiltro;

  late final _situacao = computed<SituacaoQuadras>(() {
    return switch (_catalogo.value) {
      RequestInitial() || RequestLoading() => const QuadrasCarregando(),
      RequestFailure(:final failure) => QuadrasErro(failure),
      RequestSuccess(:final data) when data.isEmpty =>
        const QuadrasCatalogoVazio(),
      RequestSuccess(:final data) => _filtrada(data),
    };
  });

  ReadonlySignal<SituacaoQuadras> get situacao => _situacao;

  SituacaoQuadras _filtrada(List<Quadra> data) {
    final visiveis =
        filtrarQuadras(data, busca: _busca.value, esporte: _esporte.value);
    return visiveis.isEmpty
        ? const QuadrasSemResultado()
        : QuadrasLista(visiveis);
  }

  /// Sincroniza o catálogo. Sem lista na tela, mostra o esqueleto; com lista,
  /// mantém a lista e marca [atualizando].
  Future<void> carregar() async {
    if (_descartado) return;
    final geracao = ++_geracao;
    final temLista = _catalogo.value is RequestSuccess<List<Quadra>>;
    if (temLista) {
      _atualizando.value = true;
    } else {
      _catalogo.value = const RequestLoading();
    }

    final resultado = await _repositorio.listar();
    if (_descartado || geracao != _geracao) return;

    batch(() {
      _atualizando.value = false;
      resultado.fold(
        (failure) {
          if (temLista) {
            _aviso.value = AvisoQuadras(failure.message);
          } else {
            _catalogo.value = RequestFailure(failure);
          }
        },
        (quadras) => _catalogo.value = RequestSuccess(quadras),
      );
    });
  }

  /// Puxar para atualizar.
  Future<void> atualizar() => carregar();

  void buscar(String texto) {
    if (_descartado) return;
    _busca.value = texto;
  }

  void selecionarEsporte(TipoEsporte? esporte) {
    if (_descartado) return;
    _esporte.value = esporte;
  }

  void limparFiltros() {
    if (_descartado) return;
    batch(() {
      _busca.value = '';
      _esporte.value = null;
    });
  }

  void consumirAviso() {
    if (_descartado) return;
    _aviso.value = null;
  }

  void dispose() {
    if (_descartado) return;
    _descartado = true;
    _situacao.dispose();
    _temFiltro.dispose();
    _catalogo.dispose();
    _atualizando.dispose();
    _busca.dispose();
    _esporte.dispose();
    _aviso.dispose();
  }
}
