import 'package:so_mais_uma/src/imports/imports.dart';

import 'minhas_reservas_store.dart';
import 'minhas_reservas_view.dart';
import 'recarga_ao_voltar.dart';

/// Aba "Reservas" do shell CLIENTE (`/reservas`).
class MinhasReservasScreen extends StatefulWidget {
  const MinhasReservasScreen({super.key});

  @override
  State<MinhasReservasScreen> createState() => _MinhasReservasScreenState();
}

class _MinhasReservasScreenState extends State<MinhasReservasScreen>
    with RecargaAoVoltar<MinhasReservasScreen> {
  late final MinhasReservasStore _store;
  late final EffectCleanup _limparAviso;

  @override
  String get caminhoDaTela => AppRoutes.reservas;

  @override
  void initState() {
    super.initState();
    _store = injector.get<MinhasReservasStore>();
    _store.carregar();
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

  /// Volta de DetalheReserva/Pagamento ou troca de aba: recarrega a lista.
  @override
  void aoVoltarParaTela() => _store.carregar();

  Future<void> _comoChegar(Reserva reserva) async {
    final quadra = _store.quadras.value[reserva.quadraId];
    final resultado = await UrlLauncherService.instance.abrirMapa(
      latitude: quadra?.latitude,
      longitude: quadra?.longitude,
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

  @override
  void dispose() {
    _limparAviso();
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) => MinhasReservasView(
        estado: _store.estado.value,
        aba: _store.aba.value,
        abas: _store.abas.value,
        quadras: _store.quadras.value,
        agora: _store.agora,
        onAtualizar: _store.carregar,
        onTentarNovamente: _store.carregar,
        onSelecionarAba: _store.selecionarAba,
        onVerTodoHistorico: _store.verTodoHistorico,
        onPagar: (r) => context.push(AppRoutes.pagamento(r.id)),
        onDetalhes: (r) => context.push(AppRoutes.reserva(r.id)),
        onComoChegar: _comoChegar,
        onEncontrarQuadras: () => context.go(AppRoutes.quadras),
      ),
    );
  }
}
