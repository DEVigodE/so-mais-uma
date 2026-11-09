import 'package:so_mais_uma/src/imports/imports.dart';

import 'quadras_store.dart';
import 'quadras_view.dart';

/// Tela Quadras (`/quadras`, aba 0 do shell CLIENTE).
class QuadrasScreen extends StatefulWidget {
  const QuadrasScreen({super.key});

  @override
  State<QuadrasScreen> createState() => _QuadrasScreenState();
}

class _QuadrasScreenState extends State<QuadrasScreen> {
  late final QuadrasStore _store;
  final _buscaController = TextEditingController();

  /// Espera de 300 ms da busca enquanto o usuário digita (spec).
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 300));
  late final EffectCleanup _limparEfeitoAviso;

  @override
  void initState() {
    super.initState();
    _store = injector.get<QuadrasStore>();
    _limparEfeitoAviso = effect(() {
      final aviso = _store.aviso.value;
      if (aviso == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showAppSnack(context, aviso.mensagem, type: SnackBarType.error);
        _store.consumirAviso();
      });
      // Garante um quadro para o callback rodar mesmo sem rebuild.
      WidgetsBinding.instance.ensureVisualUpdate();
    });
    _store.carregar();
  }

  @override
  void dispose() {
    _limparEfeitoAviso();
    _debouncer.dispose();
    _buscaController.dispose();
    _store.dispose();
    super.dispose();
  }

  void _aoBuscar(String texto) {
    if (texto.isEmpty) {
      _debouncer.dispose();
      _store.buscar('');
      return;
    }
    _debouncer.run(() {
      if (mounted) _store.buscar(texto);
    });
  }

  void _limparFiltros() {
    _debouncer.dispose();
    _buscaController.clear();
    _store.limparFiltros();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) => QuadrasView(
        situacao: _store.situacao.value,
        esporte: _store.esporte.value,
        buscaController: _buscaController,
        onBusca: _aoBuscar,
        onEsporte: _store.selecionarEsporte,
        onLimparFiltros: _limparFiltros,
        onAtualizar: _store.atualizar,
        onTentarNovamente: _store.carregar,
        onAbrirQuadra: (quadra) => context.push(AppRoutes.quadra(quadra.id)),
      ),
    );
  }
}
