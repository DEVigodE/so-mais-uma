import 'package:equatable/equatable.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../shared/domain/brasilia.dart';
import '../../../../shared/domain/entities/horario_funcionamento.dart';
import '../../../../shared/domain/entities/quadra.dart';
import '../../../../shared/domain/entities/reserva.dart';
import '../../../../shared/domain/repositories/repositorios.dart';
import '../../../../utils/async_state.dart';
import '../../../../utils/failure.dart';
import 'minhas_quadras_calculos.dart';

/// Eventos de uma leitura para o contêiner (snackbar e diálogo).
sealed class EventoMinhasQuadras {
  const EventoMinhasQuadras();
}

/// 204 no `DELETE /quadras/{id}`.
final class QuadraDesativada extends EventoMinhasQuadras {
  const QuadraDesativada(this.nome);

  final String nome;
}

/// 409 `QUADRA_COM_RESERVAS`: diálogo com o atalho "Ver reservas".
final class DesativacaoBloqueada extends EventoMinhasQuadras {
  const DesativacaoBloqueada(this.quadraId);

  final int quadraId;
}

/// 403: "Você não tem permissão para isso".
final class SemPermissao extends EventoMinhasQuadras {
  const SemPermissao();
}

/// Outra falha de uma ação ou de uma atualização com a lista já na tela.
final class FalhaMinhasQuadras extends EventoMinhasQuadras {
  const FalhaMinhasQuadras(this.mensagem);

  final String mensagem;
}

/// Números do painel em degradê.
class ResumoPainel extends Equatable {
  const ResumoPainel({
    required this.hoje,
    this.totalQuadras,
    this.reservasHoje,
  });

  /// Instante de referência ("Hoje, 24 de Outubro").
  final DateTime hoje;

  /// Nulo enquanto a lista não carregou.
  final int? totalQuadras;

  /// Nulo enquanto as reservas não carregaram (ou falharam).
  final int? reservasHoje;

  @override
  List<Object?> get props => [hoje, totalQuadras, reservasHoje];
}

/// Estado de MinhasQuadras (`/dono/quadras`, aba 0 do shell DONO).
///
/// A lista vem de `GET /quadras/minhas`; as métricas do dia são calculadas
/// (D14) com `GET /reservas` (o dono recebe as reservas das suas quadras) e
/// com as faixas de cada quadra ativa, buscadas sem bloquear a lista, porque
/// a listagem não traz `horariosFuncionamento`.
class MinhasQuadrasStore {
  MinhasQuadrasStore(
    this._quadras,
    this._reservas,
    this._horarios,
    this._relogio,
  ) : _agora = signal(_relogio.agora());

  final QuadraRepository _quadras;
  final ReservaRepository _reservas;
  final HorarioRepository _horarios;
  final Relogio _relogio;

  static const String codigoQuadraComReservas = 'QUADRA_COM_RESERVAS';

  bool _descartado = false;

  final Signal<DateTime> _agora;
  final _estado = signal<RequestState<List<Quadra>>>(const RequestInitial());
  final _listaReservas = signal<List<Reserva>?>(null);
  final _faixas = signal<Map<int, List<HorarioFuncionamento>>>(const {});
  final _desativando = signal<Set<int>>(const {});
  final _evento = signal<EventoMinhasQuadras?>(null);

  /// Carga da lista; mantém o sucesso anterior durante as atualizações.
  ReadonlySignal<RequestState<List<Quadra>>> get estado => _estado;

  /// Ids das quadras com `DELETE` em andamento.
  ReadonlySignal<Set<int>> get desativando => _desativando;
  ReadonlySignal<EventoMinhasQuadras?> get evento => _evento;

  /// Cards na ordem "Mais ativas", com a atividade do dia.
  late final ReadonlySignal<List<QuadraComAtividade>> cards = computed(() {
    final estado = _estado.value;
    if (estado is! RequestSuccess<List<Quadra>>) return const [];
    final agora = _agora.value;
    final reservas = _listaReservas.value;
    final faixas = _faixas.value;
    return ordenarMaisAtivas(
      estado.data.map(
        (q) => QuadraComAtividade(
          q,
          calcularAtividade(
            quadraId: q.id,
            reservas: reservas,
            horarios: faixas[q.id],
            agora: agora,
          ),
        ),
      ),
    );
  });

  late final ReadonlySignal<ResumoPainel> resumo = computed(() {
    final estado = _estado.value;
    final agora = _agora.value;
    final reservas = _listaReservas.value;
    return ResumoPainel(
      hoje: agora,
      totalQuadras: estado is RequestSuccess<List<Quadra>>
          ? totalDeQuadras(estado.data)
          : null,
      reservasHoje:
          reservas == null ? null : reservasConfirmadasHoje(reservas, agora),
    );
  });

  /// Busca a lista e as reservas; depois, em segundo plano, as faixas das
  /// quadras ativas. Completa quando a lista e as reservas chegam.
  Future<void> carregar() async {
    _agora.value = _relogio.agora();
    final jaTemLista = _estado.value is RequestSuccess<List<Quadra>>;
    if (!jaTemLista) _estado.value = const RequestLoading();

    final quadrasFuturo = _quadras.minhas();
    final reservasFuturo = _reservas.listar();
    final quadras = await quadrasFuturo;
    final reservas = await reservasFuturo;
    if (_descartado) return;

    quadras.fold(
      (falha) {
        if (jaTemLista) {
          _evento.value = FalhaMinhasQuadras(falha.message);
        } else {
          _estado.value = RequestFailure(falha);
        }
      },
      (lista) {
        batch(() {
          _estado.value = RequestSuccess(List.unmodifiable(lista));
          reservas.fold(
              (_) {}, (r) => _listaReservas.value = List.unmodifiable(r));
        });
        _carregarFaixas(lista);
      },
    );
  }

  /// `DELETE /quadras/{id}` (o contêiner já confirmou com o dono).
  Future<void> desativar(Quadra quadra) async {
    if (_desativando.value.contains(quadra.id)) return;
    _desativando.value = Set.unmodifiable({..._desativando.value, quadra.id});

    final resultado = await _quadras.desativar(quadra.id);
    if (_descartado) return;
    _desativando.value =
        Set.unmodifiable({..._desativando.value}..remove(quadra.id));

    resultado.fold(
      (falha) => _evento.value = switch (falha) {
        ApiFailure(status: 409) => DesativacaoBloqueada(quadra.id),
        ApiFailure(status: 403) => const SemPermissao(),
        _ => FalhaMinhasQuadras(falha.message),
      },
      (_) {
        batch(() {
          _substituir(quadra.copyWith(ativa: false));
          _evento.value = QuadraDesativada(quadra.nome);
        });
        carregar();
      },
    );
  }

  void consumirEvento() => _evento.value = null;

  void _substituir(Quadra quadra) {
    final estado = _estado.value;
    if (estado is! RequestSuccess<List<Quadra>>) return;
    _estado.value = RequestSuccess(List.unmodifiable(
      estado.data.map((q) => q.id == quadra.id ? quadra : q),
    ));
  }

  /// Faixas de cada quadra ativa, uma requisição por quadra, sem bloquear.
  /// Falha deixa a faixa desconhecida (o card omite a ocupação).
  Future<void> _carregarFaixas(List<Quadra> quadras) async {
    await Future.wait(
      quadras.where((q) => q.ativa).map((q) async {
        final r = await _horarios.listar(q.id);
        if (_descartado) return;
        r.fold((_) {}, (lista) {
          _faixas.value = Map.unmodifiable({
            ..._faixas.value,
            q.id: List<HorarioFuncionamento>.unmodifiable(lista),
          });
        });
      }),
    );
  }

  void dispose() {
    _descartado = true;
    cards.dispose();
    resumo.dispose();
    _agora.dispose();
    _estado.dispose();
    _listaReservas.dispose();
    _faixas.dispose();
    _desativando.dispose();
    _evento.dispose();
  }
}
