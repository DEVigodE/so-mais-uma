import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../theme/app_borders.dart';
import '../../app_assets.dart';

/// Logo do "Só mais uma" (SVG do protótipo), com cantos arredondados.
class LogoApp extends StatelessWidget {
  const LogoApp({super.key, this.tamanho = 32, this.semanticsLabel});

  final double tamanho;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppBorders.sm,
      child: SvgPicture.asset(
        AppAssets.logo,
        width: tamanho,
        height: tamanho,
        semanticsLabel: semanticsLabel,
        excludeFromSemantics: semanticsLabel == null,
      ),
    );
  }
}
