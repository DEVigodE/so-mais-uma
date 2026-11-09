import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_shadows.dart';

/// Item da bottom-nav de um shell.
class ItemNavegacao {
  const ItemNavegacao({required this.icone, required this.rotuloKey});

  final IconData icone;
  final String rotuloKey;
}

/// Itens do shell CLIENTE (docs/04 §4.4).
const itensCliente = [
  ItemNavegacao(icone: Icons.sports_soccer, rotuloKey: 'navegacao.quadras'),
  ItemNavegacao(icone: Icons.event_available, rotuloKey: 'navegacao.reservas'),
  ItemNavegacao(icone: Icons.person_outline, rotuloKey: 'navegacao.perfil'),
];

/// Itens do shell DONO (docs/04 §4.4).
const itensDono = [
  ItemNavegacao(icone: Icons.stadium_outlined, rotuloKey: 'navegacao.minhas_quadras'),
  ItemNavegacao(icone: Icons.event_note_outlined, rotuloKey: 'navegacao.reservas'),
  ItemNavegacao(icone: Icons.person_outline, rotuloKey: 'navegacao.perfil'),
];

/// Scaffold de um `StatefulShellRoute.indexedStack` com a bottom-nav do
/// protótipo: indicador em pílula (`primary-fixed` a 40 %) e rótulo em
/// `primary` na aba ativa. Tocar a aba atual volta à raiz da aba.
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({
    super.key,
    required this.navigationShell,
    required this.itens,
  });

  final StatefulNavigationShell navigationShell;
  final List<ItemNavegacao> itens;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BarraNavegacaoInferior(
        itens: itens,
        indiceAtual: navigationShell.currentIndex,
        onSelecionar: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

class BarraNavegacaoInferior extends StatelessWidget {
  const BarraNavegacaoInferior({
    super.key,
    required this.itens,
    required this.indiceAtual,
    required this.onSelecionar,
  });

  final List<ItemNavegacao> itens;
  final int indiceAtual;
  final ValueChanged<int> onSelecionar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.95),
        boxShadow: AppShadows.bottomBar,
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Row(
            children: [
              for (var i = 0; i < itens.length; i++)
                Expanded(
                  child: _ItemBarra(
                    item: itens[i],
                    ativo: i == indiceAtual,
                    onTap: () => onSelecionar(i),
                    cs: cs,
                    tt: tt,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemBarra extends StatelessWidget {
  const _ItemBarra({
    required this.item,
    required this.ativo,
    required this.onTap,
    required this.cs,
    required this.tt,
  });

  final ItemNavegacao item;
  final bool ativo;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final cor = ativo ? cs.primary : cs.onSurfaceVariant;
    return Semantics(
      selected: ativo,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                decoration: BoxDecoration(
                  color: ativo
                      ? cs.primaryFixed.withValues(alpha: 0.4)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(item.icone, size: 24, color: cor),
              ),
              const SizedBox(height: 4),
              Text(
                item.rotuloKey.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelSmall?.copyWith(
                  color: cor,
                  fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
