import 'dart:async';

import 'package:so_mais_uma/src/imports/imports.dart';
import 'package:so_mais_uma/src/routing/router_refresh.dart';

/// Splash do protótipo (`splash_screen/code.html`).
///
/// Fica na tela por no mínimo 1 s (design D9); depois disso o `redirect` leva
/// ao Login ou à home do perfil assim que a sessão estiver resolvida. Saem o
/// par "CONNECTING"/"FastBoot" e a marcação "RNF08 / RNF11".
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const Duration minimo = Duration(seconds: 1);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _mensagens = [
    'splash.status_partidas',
    'splash.status_quadras',
    'splash.status_pronto',
  ];

  Timer? _minimo;
  Timer? _status;
  var _passo = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
    _minimo = Timer(SplashScreen.minimo, SplashGate.instance.concluir);
    _status = Timer.periodic(const Duration(milliseconds: 1400), (t) {
      if (_passo >= _mensagens.length - 1) {
        t.cancel();
        return;
      }
      setState(() => _passo++);
    });
  }

  @override
  void dispose() {
    _minimo?.cancel();
    _status?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = context.textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      // `expand` dá ao conteúdo a largura da tela; com o `loose` padrão a
      // Column encolhe até o filho mais largo e fica presa no canto esquerdo.
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.2,
                child: CustomPaint(painter: _CampoPainter(cs.primary)),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xl,
              ),
              child: Column(
                children: [
                  const Spacer(),
                  _LogoComBrilho(cs: cs),
                  SizedBox(height: AppSpacing.lg),
                  Text(
                    'splash.sobretitulo'.tr().toUpperCase(),
                    textAlign: TextAlign.center,
                    style: tt.labelMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.4,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Semantics(
                    header: true,
                    child: Text(
                      'comum.app_nome'.tr(),
                      textAlign: TextAlign.center,
                      style: tt.displayMedium?.copyWith(color: cs.onSurface),
                    ),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    'splash.slogan'.tr(),
                    textAlign: TextAlign.center,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xl + AppSpacing.sm),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          strokeWidth: 3,
                          color: cs.primary,
                          backgroundColor: cs.primary.withValues(alpha: 0.2),
                        ),
                        Icon(Icons.timer_outlined, size: 14, color: cs.primary),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSpacing.ms),
                  AnimatedSwitcher(
                    duration: AppDurations.normal,
                    child: Text(
                      _mensagens[_passo].tr(),
                      key: ValueKey(_passo),
                      textAlign: TextAlign.center,
                      style: tt.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: AppBorders.full,
                      boxShadow: AppShadows.subtle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.s6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user, size: 14, color: cs.primary),
                          SizedBox(width: AppSpacing.sm),
                          Text(
                            'splash.modo_seguro'.tr(),
                            style: tt.labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoComBrilho extends StatelessWidget {
  const _LogoComBrilho({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: cs.primaryFixed.withValues(alpha: 0.4),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          Container(
            width: 128,
            height: 128,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: AppBorders.md,
              boxShadow: AppShadows.modal,
            ),
            child: LogoApp(
              tamanho: 104,
              semanticsLabel: 'comum.app_nome'.tr(),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
                boxShadow: AppShadows.card,
              ),
              child: Icon(Icons.sports_soccer, size: 16, color: cs.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Linhas do campo ao fundo (SVG decorativo do protótipo, 400×800).
class _CampoPainter extends CustomPainter {
  const _CampoPainter(this.cor);

  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 400;
    final sy = size.height / 800;
    final traco = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final centro = Offset(200 * sx, 400 * sy);

    // Círculo central tracejado.
    final raio = 160 * sx;
    const segmentos = 84;
    for (var i = 0; i < segmentos; i += 2) {
      canvas.drawArc(
        Rect.fromCircle(center: centro, radius: raio),
        i * 2 * 3.14159 / segmentos,
        2 * 3.14159 / segmentos,
        false,
        traco,
      );
    }
    canvas
      ..drawLine(Offset(40 * sx, 400 * sy), Offset(360 * sx, 400 * sy), traco)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(70 * sx, 240 * sy, 260 * sx, 320 * sy),
          Radius.circular(28 * sx),
        ),
        traco,
      )
      ..drawCircle(
        centro,
        12 * sx,
        Paint()..color = cor.withValues(alpha: 0.3),
      );
  }

  @override
  bool shouldRepaint(_CampoPainter oldDelegate) => oldDelegate.cor != cor;
}
