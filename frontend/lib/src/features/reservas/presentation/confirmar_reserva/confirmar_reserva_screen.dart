import 'package:so_mais_uma/src/imports/imports.dart';

import 'confirmar_reserva_store.dart';
import 'confirmar_reserva_view.dart';

/// ConfirmarReserva (`/quadras/:id/reservar?inicio=`), aberta com
/// `push<bool>` pela grade; devolve `true` para pedir recarga da grade.
class ConfirmarReservaScreen extends StatefulWidget {
  const ConfirmarReservaScreen({
    super.key,
    required this.quadraId,
    required this.inicio,
  });

  final int quadraId;

  /// Instante do slot escolhido.
  final DateTime inicio;

  @override
  State<ConfirmarReservaScreen> createState() => _ConfirmarReservaScreenState();
}

class _ConfirmarReservaScreenState extends State<ConfirmarReservaScreen> {
  late final ConfirmarReservaStore _store;
  final _observacaoController = TextEditingController();
  late final EffectCleanup _limparEfeitoEvento;

  @override
  void initState() {
    super.initState();
    _store = injector.get<ConfirmarReservaStore>();
    _limparEfeitoEvento = effect(() {
      final evento = _store.evento.value;
      if (evento == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _store.consumirEvento();
        _tratar(evento);
      });
      // Garante um quadro para o callback rodar mesmo sem rebuild.
      WidgetsBinding.instance.ensureVisualUpdate();
    });
    _store.carregar(widget.quadraId, widget.inicio);
  }

  @override
  void dispose() {
    _limparEfeitoEvento();
    _observacaoController.dispose();
    _store.dispose();
    super.dispose();
  }

  Future<void> _tratar(EventoConfirmacao evento) async {
    switch (evento) {
      case IrParaPagamento(:final reservaId):
        context.go(AppRoutes.pagamento(reservaId));
      case HorarioIndisponivel():
        _avisarEVoltar(
          'reservas.confirmar.horario_indisponivel'.tr(),
          recarregar: true,
        );
      case PagamentoIndisponivel():
        await showDialog<void>(
          context: context,
          builder: (context) => const DialogoPagamentoIndisponivel(),
        );
        if (!mounted) return;
        _voltarParaGrade(recarregar: true);
      case HorarioForaDaRegra(:final mensagem):
        _avisarEVoltar(mensagem, recarregar: true);
      case InicioNoPassado():
        // Recarrega para a grade mostrar o slot como passado.
        _avisarEVoltar(
          'reservas.confirmar.inicio_passado'.tr(),
          recarregar: true,
        );
      case QuadraIndisponivel():
        _avisarEVoltar(
          'reservas.confirmar.nao_encontrada'.tr(),
          recarregar: false,
        );
      case ReservaPendenteExistente(:final reservaId):
        final ir = await showAppAlertDialog(
          context,
          title: 'reservas.confirmar.pendente_titulo'.tr(),
          message: 'reservas.confirmar.pendente_mensagem'.tr(),
          confirmLabel: 'reservas.confirmar.pendente_ir'.tr(),
          cancelLabel: 'comum.fechar'.tr(),
        );
        if (!mounted || ir != true) return;
        context.go(
          reservaId == null ? AppRoutes.reservas : AppRoutes.reserva(reservaId),
        );
      case FalhaConfirmacao(:final failure):
        showAppSnack(context, failure.message, type: SnackBarType.error);
    }
  }

  /// Snackbar e volta à DetalheQuadra; com [recarregar], devolve `true` para
  /// a grade recarregar.
  void _avisarEVoltar(String mensagem, {required bool recarregar}) {
    showAppSnack(context, mensagem, type: SnackBarType.warning);
    _voltarParaGrade(recarregar: recarregar);
  }

  void _voltarParaGrade({required bool recarregar}) {
    if (context.canPop()) {
      context.pop(recarregar ? true : null);
    } else {
      context.go(AppRoutes.quadra(widget.quadraId));
    }
  }

  void _voltar() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.quadra(widget.quadraId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) => ConfirmarReservaView(
        quadra: _store.quadra.value,
        inicio: _store.inicio.value,
        naoEncontrada: _store.naoEncontrada.value,
        observacaoController: _observacaoController,
        tamanhoObservacao: _store.observacao.value.length,
        enviando: _store.enviando.value,
        podeConfirmar: _store.podeConfirmar.value,
        onObservacao: _store.alterarObservacao,
        onConfirmar: _store.confirmar,
        onTentarNovamente: _store.tentarNovamente,
        onVoltar: _voltar,
      ),
    );
  }
}
