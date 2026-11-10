import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import '../../../config/injector.dart';
import '../../../theme/app_shadows.dart';
import '../../session/session_store.dart';
import 'avatar_iniciais.dart';
import 'logo_app.dart';

/// Barra superior fixa do protótipo (`<header>` dos `code.html`):
/// [voltar] + logo + bloco de título + [acoes] + avatar de iniciais.
///
/// - [sobretitulo]: rótulo pequeno acima do título (ex.: "SÓ MAIS UMA" em
///   MinhasReservas, em `primary`, caixa alta).
/// - [subtitulo]: widget abaixo do título (ex.: "Área do Proprietário").
/// - [mostrarVoltar]: `null` decide por `Navigator.canPop(context)`.
/// - [onVoltar]: substitui o `pop` (ex.: Pagamento volta para MinhasReservas).
class BarraSuperior extends StatelessWidget implements PreferredSizeWidget {
  const BarraSuperior({
    super.key,
    required this.titulo,
    this.sobretitulo,
    this.subtitulo,
    this.tituloStyle,
    this.acoes = const [],
    this.mostrarVoltar,
    this.onVoltar,
    this.mostrarAvatar = true,
    this.onAvatar,
  });

  final String titulo;
  final String? sobretitulo;
  final Widget? subtitulo;
  final TextStyle? tituloStyle;
  final List<Widget> acoes;
  final bool? mostrarVoltar;
  final VoidCallback? onVoltar;
  final bool mostrarAvatar;
  final VoidCallback? onAvatar;

  static const double altura = 64;

  @override
  Size get preferredSize => const Size.fromHeight(altura);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // `Navigator.canPop` funciona com e sem GoRouter (widget tests).
    final voltar =
        mostrarVoltar ?? (onVoltar != null || Navigator.canPop(context));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        boxShadow: AppShadows.topBar,
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: altura,
          child: Padding(
            padding: EdgeInsets.only(left: voltar ? 4 : 16, right: 8),
            child: Row(
              children: [
                if (voltar)
                  IconButton(
                    tooltip: 'comum.voltar'.tr(),
                    icon: const Icon(Icons.arrow_back),
                    // `maybePop` respeita o `PopScope` (diálogo de descartar).
                    onPressed:
                        onVoltar ?? () => Navigator.of(context).maybePop(),
                  ),
                const LogoApp(),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sobretitulo != null)
                        Text(
                          sobretitulo!.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelSmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      Semantics(
                        header: true,
                        child: Text(
                          titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tituloStyle ??
                              tt.titleMedium?.copyWith(color: cs.onSurface),
                        ),
                      ),
                      if (subtitulo != null) subtitulo!,
                    ],
                  ),
                ),
                ...acoes,
                if (mostrarAvatar) _AvatarSessao(onTap: onAvatar),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarSessao extends StatelessWidget {
  const _AvatarSessao({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sessao = injector.get<SessionStore>();
    return SignalBuilder(
      builder: (context) {
        final usuario = sessao.user.value;
        final avatar = AvatarIniciais(
          iniciais: usuario?.iniciais ?? '?',
          semanticsLabel: 'comum.perfil'.tr(),
        );
        return SizedBox(
          width: 44,
          height: 44,
          child: onTap == null
              ? Center(child: avatar)
              : InkResponse(onTap: onTap, radius: 22, child: Center(child: avatar)),
        );
      },
    );
  }
}
