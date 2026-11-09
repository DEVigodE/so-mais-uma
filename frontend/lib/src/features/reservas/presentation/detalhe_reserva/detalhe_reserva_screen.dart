import 'package:so_mais_uma/src/imports/imports.dart';

import '../cancelamento/cancelamento_cliente_sheet.dart';
import '../minhas_reservas/recarga_ao_voltar.dart';
import 'detalhe_reserva_store.dart';
import 'detalhe_reserva_view.dart';

/// DetalheReserva (`/reservas/:id`).
class DetalheReservaScreen extends StatefulWidget {
  const DetalheReservaScreen({
    super.key,
    required this.reservaId,
  });

  final int reservaId;

  @override
  State<DetalheReservaScreen> createState() => _DetalheReservaScreenState();
}

class _DetalheReservaScreenState extends State<DetalheReservaScreen>
    with RecargaAoVoltar<DetalheReservaScreen> {
  late final DetalheReservaStore _store;
  late final EffectCleanup _limparAviso;
  final _observacao = TextEditingController();

  @override
  String get caminhoDaTela => AppRoutes.reserva(widget.reservaId);

  @override
  void initState() {
    super.initState();
    _store = injector.get<DetalheReservaStore>();
    _store.carregar(widget.reservaId);
    _limparAviso = effect(() {
      final aviso = _store.aviso.value;
      if (aviso == null) return;
      Future.microtask(() {
        if (!mounted) return;
        _store.consumirAviso();
        aviso.mostrar(context);
      });
    });
  }

  /// Volta do Pagamento (`go` depois de PAGO/CANCELADO): recarrega.
  @override
  void aoVoltarParaTela() => _store.recarregar();

  Reserva? get _reserva => switch (_store.estado.value) {
        RequestSuccess(:final data) => data,
        _ => null,
      };

  Future<void> _copiar(String texto, ItemCopiado item) async {
    final resultado = await CopyService.instance.copy(texto);
    if (!mounted) return;
    resultado.fold(
      (falha) => showAppSnack(context, falha.message, type: SnackBarType.error),
      (_) => _store.marcarCopiado(item),
    );
  }

  Future<void> _comoChegar() async {
    final reserva = _reserva;
    if (reserva == null) return;
    final quadra = _store.quadra.value;
    final resultado = await UrlLauncherService.instance.abrirMapa(
      nome: reserva.quadraNome,
      endereco: reserva.quadraEndereco ?? quadra?.enderecoCompleto,
    );
    if (!mounted) return;
    resultado.fold(
      (_) => showAppSnack(
        context,
        'comum.nenhum_app_mapas'.tr(),
        type: SnackBarType.error,
      ),
      (_) {},
    );
  }

  void _editar() {
    _observacao.text = _reserva?.observacao ?? '';
    _store.iniciarEdicao();
  }

  Future<void> _cancelarReserva() async {
    final reserva = _reserva;
    if (reserva == null) return;
    final cancelou = await mostrarCancelamentoCliente(context, reserva);
    if (cancelou && mounted) await _store.recarregar();
  }

  void _voltarErro() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.reservas);
    }
  }

  @override
  void dispose() {
    _limparAviso();
    _store.dispose();
    _observacao.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) => DetalheReservaView(
        estado: _store.estado.value,
        quadra: _store.quadra.value,
        agora: _store.agora.value,
        prazo: _store.prazo.value,
        podeEditar: _store.podeEditarObservacao.value,
        editando: _store.editando.value,
        salvando: _store.salvando.value,
        observacaoSalva: _store.observacaoSalva.value,
        copiado: _store.copiado.value,
        usuario: _store.usuario.value,
        observacaoController: _observacao,
        onVoltarErro: _voltarErro,
        onTentarNovamente: _store.recarregar,
        onCopiarCodigo: () {
          final reserva = _reserva;
          if (reserva != null) {
            _copiar(codigoReserva(reserva.id), ItemCopiado.codigo);
          }
        },
        onCopiarTxid: () {
          final txid = _reserva?.pagamento?.txid;
          if (txid != null) _copiar(txid, ItemCopiado.txid);
        },
        onComoChegar: _comoChegar,
        onEditar: _editar,
        onCancelarEdicao: _store.cancelarEdicao,
        onSalvar: () => _store.salvarObservacao(_observacao.text),
        onCancelarReserva: _cancelarReserva,
        onPagar: () => context.push(AppRoutes.pagamento(widget.reservaId)),
        onVoltarMinhasReservas: () => context.go(AppRoutes.reservas),
        onBuscarQuadras: () => context.go(AppRoutes.quadras),
      ),
    );
  }
}
