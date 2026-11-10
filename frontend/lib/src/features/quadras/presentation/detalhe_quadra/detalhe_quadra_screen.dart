import 'package:so_mais_uma/src/imports/imports.dart';

import 'detalhe_quadra_store.dart';
import 'detalhe_quadra_view.dart';

export 'detalhe_quadra_view.dart'
    show ConstrutorSecaoReserva, LayoutSecaoReserva;

/// DetalheQuadra (`/quadras/:id` do CLIENTE e `/dono/quadras/:id` do DONO).
class DetalheQuadraScreen extends StatefulWidget {
  const DetalheQuadraScreen({
    super.key,
    required this.quadraId,
    this.modoDono = false,
    this.secaoReserva,
  });

  /// Id da quadra (`/quadras/:id` ou `/dono/quadras/:id`).
  final int quadraId;

  /// `true` na rota do DONO: só a parte estática, sem grade nem barra.
  final bool modoDono;

  /// Seção de grade e reserva, composta pelo router (feature `reservas`).
  /// Recebe a quadra carregada e um `layout(secao, barra)`: a seção vai no fim
  /// da rolagem e a barra "Horário selecionado" fica fixa no rodapé.
  final ConstrutorSecaoReserva? secaoReserva;

  @override
  State<DetalheQuadraScreen> createState() => _DetalheQuadraScreenState();
}

class _DetalheQuadraScreenState extends State<DetalheQuadraScreen> {
  late final DetalheQuadraStore _store;

  @override
  void initState() {
    super.initState();
    _store = injector.get<DetalheQuadraStore>();
    _store.carregar(widget.quadraId);
  }

  @override
  void didUpdateWidget(covariant DetalheQuadraScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quadraId != widget.quadraId) {
      _store.carregar(widget.quadraId);
    }
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  Future<void> _abrirMapa(Quadra quadra) async {
    final resultado = await UrlLauncherService.instance.abrirMapa(
      latitude: quadra.latitude,
      longitude: quadra.longitude,
      nome: quadra.nome,
      endereco: quadra.enderecoCompleto,
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

  void _voltar() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(widget.modoDono ? AppRoutes.donoQuadras : AppRoutes.quadras);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) => DetalheQuadraView(
        estado: _store.estado.value,
        grupos: _store.gruposFuncionamento.value,
        naoEncontrada: _store.naoEncontrada.value,
        onTentarNovamente: _store.tentarNovamente,
        onVoltar: _voltar,
        onAbrirMapa: _abrirMapa,
        secaoReserva: widget.modoDono ? null : widget.secaoReserva,
      ),
    );
  }
}
