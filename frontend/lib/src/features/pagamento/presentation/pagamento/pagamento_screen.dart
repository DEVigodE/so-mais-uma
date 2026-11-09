import 'package:flutter/semantics.dart';
import 'package:so_mais_uma/src/imports/imports.dart';

import 'pagamento_store.dart';
import 'pagamento_view.dart';

/// Tela Pagamento (`/reservas/:id/pagamento`).
///
/// Voltar (seta, back do sistema e "Voltar para Minhas Reservas") faz `go`
/// para `/reservas`, nunca voltando à ConfirmarReserva.
class PagamentoScreen extends StatefulWidget {
  const PagamentoScreen({
    super.key,
    required this.reservaId,
    required this.cancelar,
  });

  final int reservaId;

  /// Abre o sheet de cancelamento do cliente (feature `reservas`, composto
  /// pelo router). Devolve `true` quando a reserva foi cancelada.
  final Future<bool> Function(BuildContext context, Reserva reserva) cancelar;

  @override
  State<PagamentoScreen> createState() => _PagamentoScreenState();
}

class _PagamentoScreenState extends State<PagamentoScreen> {
  late final PagamentoStore _store;
  late final AppLifecycleListener _ciclo;
  final List<EffectCleanup> _efeitos = [];

  @override
  void initState() {
    super.initState();
    _store = injector.get<PagamentoStore>();
    _store.carregar(widget.reservaId);
    _ciclo = AppLifecycleListener(
      onHide: _store.aoOcultarApp,
      onShow: _store.aoMostrarApp,
    );
    _efeitos
      ..add(effect(() {
        final destino = _store.navegacao.value;
        if (destino == null) return;
        Future.microtask(() {
          if (!mounted) return;
          _store.consumirNavegacao();
          if (destino == DestinoPagamento.detalheCancelada) {
            showAppSnack(context, 'pagamento.reserva_cancelada'.tr());
          }
          context.go(AppRoutes.reserva(widget.reservaId));
        });
      }))
      ..add(effect(() {
        final aviso = _store.aviso.value;
        if (aviso == null) return;
        Future.microtask(() {
          if (!mounted) return;
          _store.consumirAviso();
          showAppSnack(context, aviso.mensagem, type: SnackBarType.error);
        });
      }))
      ..add(effect(() {
        final marco = _store.marcoContador.value;
        if (marco == null) return;
        Future.microtask(() {
          if (!mounted) return;
          _store.consumirMarco();
          _anunciar(marco);
        });
      }));
  }

  /// Anúncio do contador ao leitor de tela só aos 5 min, 1 min e zero.
  void _anunciar(int marco) {
    final mensagem = switch (marco) {
      300 => 'pagamento.anuncio_5_min'.tr(),
      60 => 'pagamento.anuncio_1_min'.tr(),
      _ => 'pagamento.anuncio_esgotado'.tr(),
    };
    SemanticsService.sendAnnouncement(
      View.of(context),
      mensagem,
      Directionality.of(context),
    );
  }

  void _voltar() => context.go(AppRoutes.reservas);

  Future<void> _copiar() async {
    final codigo = _store.pagamento.value?.pixCopiaECola;
    if (codigo == null || codigo.isEmpty) return;
    final resultado = await CopyService.instance.copy(codigo);
    if (!mounted) return;
    resultado.fold(
      (falha) => showAppSnack(context, falha.message, type: SnackBarType.error),
      (_) => _store.marcarCopiado(),
    );
  }

  Future<void> _cancelar() async {
    final reserva = _store.reserva.value;
    if (reserva == null) return;
    _store.suspenderConsulta();
    final cancelou = await widget.cancelar(context, reserva);
    if (!mounted) return;
    if (cancelou) {
      context.go(AppRoutes.reserva(widget.reservaId));
    } else {
      _store.retomarConsulta();
    }
  }

  void _escolherOutroHorario() {
    final reserva = _store.reserva.value;
    context.go(
      reserva == null ? AppRoutes.quadras : AppRoutes.quadra(reserva.quadraId),
    );
  }

  @override
  void dispose() {
    for (final limpar in _efeitos) {
      limpar();
    }
    _ciclo.dispose();
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _voltar();
      },
      child: SignalBuilder(
        builder: (context) => PagamentoView(
          fase: _store.fase.value,
          falhaCarga: _store.falhaCarga.value,
          reserva: _store.reserva.value,
          pagamento: _store.pagamento.value,
          quadra: _store.quadra.value,
          restante: _store.restante,
          progresso: _store.progresso,
          statusVerificacao: _store.statusVerificacao.value,
          verificacaoManual: _store.verificacaoManual.value,
          simulando: _store.simulando.value,
          copiado: _store.copiado.value,
          mostrarSimulacao: kDebugMode && AppConfig.devKey.isNotEmpty,
          onVoltar: _voltar,
          onTentarNovamente: _store.tentarNovamente,
          onCopiar: _copiar,
          onJaRealizei: _store.jaRealizeiPagamento,
          onSimular: _store.simular,
          onCancelar: _cancelar,
          onEscolherOutroHorario: _escolherOutroHorario,
        ),
      ),
    );
  }
}
