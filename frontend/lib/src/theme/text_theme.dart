import 'package:flutter/material.dart';

/// Escala tipográfica do protótipo (`tailwind.config` dos `code.html`, design D2).
///
/// A altura de linha é a razão entre a linha do token e o tamanho. Os tamanhos
/// não passam pelo ScreenUtil (`.sp`), para que o `TextScaler` do sistema valha
/// sozinho até 200 % (RNF07).
///
/// | Papel | Token | Tamanho / linha / peso |
/// |---|---|---|
/// | displayLarge | display-lg | 40 / 48 / 700 |
/// | displayMedium | display-lg-mobile | 32 / 40 / 700 |
/// | headlineLarge | headline-lg | 28 / 36 / 700 |
/// | headlineMedium | headline-md | 24 / 32 / 600 |
/// | headlineSmall | headline-sm | 20 / 28 / 600 |
/// | titleLarge | title-lg | 18 / 24 / 600 |
/// | titleMedium | title-md | 16 / 22 / 600 |
/// | titleSmall | title-sm | 14 / 20 / 600 |
/// | bodyLarge / Medium / Small | body-* | 16/24/400 · 14/20/400 · 12/16/400 |
/// | labelLarge / Medium / Small | label-* | 14/20/600 · 12/16/600 · 11/14/500 |
TextTheme buildTextTheme() {
  TextStyle s(double size, double line, FontWeight weight) => TextStyle(
        fontSize: size,
        height: line / size,
        fontWeight: weight,
        letterSpacing: 0,
      );

  return TextTheme(
    displayLarge: s(40, 48, FontWeight.w700),
    displayMedium: s(32, 40, FontWeight.w700),
    displaySmall: s(28, 36, FontWeight.w700),
    headlineLarge: s(28, 36, FontWeight.w700),
    headlineMedium: s(24, 32, FontWeight.w600),
    headlineSmall: s(20, 28, FontWeight.w600),
    titleLarge: s(18, 24, FontWeight.w600),
    titleMedium: s(16, 22, FontWeight.w600),
    titleSmall: s(14, 20, FontWeight.w600),
    bodyLarge: s(16, 24, FontWeight.w400),
    bodyMedium: s(14, 20, FontWeight.w400),
    bodySmall: s(12, 16, FontWeight.w400),
    labelLarge: s(14, 20, FontWeight.w600),
    labelMedium: s(12, 16, FontWeight.w600),
    labelSmall: s(11, 14, FontWeight.w500),
  );
}
