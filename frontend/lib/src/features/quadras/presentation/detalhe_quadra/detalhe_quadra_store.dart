import 'package:so_mais_uma/src/imports/imports.dart';

import 'horarios_agrupados.dart';

/// Store da DetalheQuadra (`/quadras/:id` e `/dono/quadras/:id`): a parte
/// estática da quadra, vinda de `GET /quadras/{id}`.
class DetalheQuadraStore {
  DetalheQuadraStore(this._repositorio);

  final QuadraRepository _repositorio;

  final _estado = signal<RequestState<Quadra>>(const RequestInitial());

  int? _quadraId;
  bool _descartado = false;
  int _geracao = 0;

  ReadonlySignal<RequestState<Quadra>> get estado => _estado;

  late final _grupos = computed<List<GrupoFuncionamento>>(
    () => switch (_estado.value) {
      RequestSuccess(:final data) => agruparHorarios(data.horarios),
      _ => const [],
    },
  );

  /// Linhas agrupadas do cartão "Horários de Funcionamento" (vazio = sem
  /// horários cadastrados).
  ReadonlySignal<List<GrupoFuncionamento>> get gruposFuncionamento => _grupos;

  late final _naoEncontrada = computed(
    () => switch (_estado.value) {
      RequestFailure(failure: final ApiFailure f) => f.naoEncontrado,
      _ => false,
    },
  );

  /// 404: a quadra não existe ou foi desativada.
  ReadonlySignal<bool> get naoEncontrada => _naoEncontrada;

  Future<void> carregar(int quadraId) async {
    if (_descartado) return;
    _quadraId = quadraId;
    final geracao = ++_geracao;
    _estado.value = const RequestLoading();

    final resultado = await _repositorio.detalhar(quadraId);
    if (_descartado || geracao != _geracao) return;

    _estado.value = resultado.fold(
      RequestFailure<Quadra>.new,
      RequestSuccess<Quadra>.new,
    );
  }

  /// "Tentar novamente" da caixa de erro.
  Future<void> tentarNovamente() async {
    final id = _quadraId;
    if (id != null) await carregar(id);
  }

  void dispose() {
    if (_descartado) return;
    _descartado = true;
    _grupos.dispose();
    _naoEncontrada.dispose();
    _estado.dispose();
  }
}
