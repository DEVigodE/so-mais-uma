import 'dart:async';

import 'package:so_mais_uma/src/imports/imports.dart';

import 'abas_reservas.dart';
import 'componentes_reserva.dart';

/// Estado de MinhasReservas (`GET /reservas`, sem `situacao`).
///
/// A lista é dividida em abas com [separarAbas] (D14). As quadras entram por
/// um join best-effort com `GET /quadras` só para foto e esporte: a lista
/// aparece sem esperar por elas, e uma quadra ausente vira placeholder.
class MinhasReservasStore {
  MinhasReservasStore(this._reservas, this._quadras, this._relogio) {
    _agora = signal(_relogio.agora());
    _minuto = computed(() => _truncarMinuto(_agora.value));
    abas = computed(() {
      final estado = _estado.value;
      if (estado is! RequestSuccess<List<Reserva>>) return AbasReservas.vazias;
      return separarAbas(estado.data, _minuto.value);
    });
    _reagendarTicker();
  }

  /// Com uma reserva pendente na tela, o contador anda a cada segundo; sem
  /// ela, "agora" só precisa virar o minuto ("Concluída").
  static const Duration tickComPendente = Duration(seconds: 1);
  static const Duration tickSemPendente = Duration(seconds: 30);

  final ReservaRepository _reservas;
  final QuadraRepository _quadras;
  final Relogio _relogio;

  final _estado = signal<RequestState<List<Reserva>>>(const RequestInitial());
  final _aba = signal(AbaReservas.proximas);
  final _quadrasPorId = signal<Map<int, Quadra>>(const {});
  final _atualizando = signal(false);
  final _aviso = signal<AvisoTela?>(null);
  late final Signal<DateTime> _agora;
  late final Computed<DateTime> _minuto;
  Timer? _ticker;
  Duration? _intervaloTicker;
  bool _descartado = false;
  int _geracao = 0;

  ReadonlySignal<RequestState<List<Reserva>>> get estado => _estado;
  ReadonlySignal<AbaReservas> get aba => _aba;
  ReadonlySignal<Map<int, Quadra>> get quadras => _quadrasPorId;

  /// Atualização em andamento com a lista já na tela (puxar para atualizar).
  ReadonlySignal<bool> get atualizando => _atualizando;

  /// Snackbar de uma atualização que falhou com dados na tela.
  ReadonlySignal<AvisoTela?> get aviso => _aviso;

  /// "Agora": a cada segundo com pendente na lista (contador dos cards),
  /// senão a cada 30 s.
  ReadonlySignal<DateTime> get agora => _agora;

  /// Abas calculadas; recalculadas quando a lista muda ou o minuto vira.
  late final ReadonlySignal<AbasReservas> abas;

  /// Busca as reservas. Com a lista na tela, mantém os dados durante a
  /// atualização e, na falha, só avisa.
  Future<void> carregar() async {
    if (_descartado) return;
    final geracao = ++_geracao;
    final temDados = _estado.value is RequestSuccess<List<Reserva>>;
    if (temDados) {
      _atualizando.value = true;
    } else {
      _estado.value = const RequestLoading();
    }

    final resultado = await _reservas.listar();
    if (_descartado || geracao != _geracao) return;

    batch(() {
      _atualizando.value = false;
      _agora.value = _relogio.agora();
      resultado.fold(
        (falha) {
          if (temDados) {
            _aviso.value = AvisoTela.texto(falha.message);
          } else {
            _estado.value = RequestFailure(falha);
          }
        },
        (lista) => _estado.value = RequestSuccess(lista),
      );
    });

    _reagendarTicker();
    final lista = resultado.getRight().toNullable();
    if (lista != null) unawaited(_carregarQuadras(lista));
  }

  void _reagendarTicker() {
    final estado = _estado.value;
    final temPendente = estado is RequestSuccess<List<Reserva>> &&
        estado.data.any((r) => r.status == StatusReserva.pendentePagamento);
    final intervalo = temPendente ? tickComPendente : tickSemPendente;
    if (_ticker != null && intervalo == _intervaloTicker) return;
    _ticker?.cancel();
    _intervaloTicker = intervalo;
    _ticker = Timer.periodic(intervalo, (_) => _tick());
  }

  /// Join best-effort: só busca quando falta alguma quadra; falha é ignorada.
  Future<void> _carregarQuadras(List<Reserva> lista) async {
    final conhecidas = _quadrasPorId.value;
    final faltando = lista.any((r) => !conhecidas.containsKey(r.quadraId));
    if (!faltando) return;
    final resultado = await _quadras.listar();
    if (_descartado) return;
    resultado.fold(
      (_) {},
      (quadras) => _quadrasPorId.value = {
        ...conhecidas,
        for (final q in quadras) q.id: q,
      },
    );
  }

  void selecionarAba(AbaReservas aba) {
    if (_descartado) return;
    _aba.value = aba;
  }

  /// "Ver todos (N)" do bloco "Histórico recente".
  void verTodoHistorico() => _aba.value = AbaReservas.historico;

  void consumirAviso() => _aviso.value = null;

  void _tick() {
    if (_descartado) return;
    _agora.value = _relogio.agora();
  }

  static DateTime _truncarMinuto(DateTime d) =>
      DateTime.fromMillisecondsSinceEpoch(
        d.millisecondsSinceEpoch - d.millisecondsSinceEpoch % 60000,
        isUtc: true,
      );

  void dispose() {
    if (_descartado) return;
    _descartado = true;
    _ticker?.cancel();
    _ticker = null;
    abas.dispose();
    _minuto.dispose();
    _agora.dispose();
    _estado.dispose();
    _aba.dispose();
    _quadrasPorId.dispose();
    _atualizando.dispose();
    _aviso.dispose();
  }
}
