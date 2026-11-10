import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'text_theme.dart';
import 'color_schemes.dart';

Color _colorFromHex(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  return Color(int.parse('ff$cleaned', radix: 16));
  }

/// Custom theme extension for spacing and other design tokens
class AppDesignTokens extends ThemeExtension<AppDesignTokens> {
  const AppDesignTokens({
    required this.paddingSmall,
    required this.paddingMedium,
    required this.paddingLarge,
    required this.borderRadiusSmall,
    required this.borderRadiusMedium,
    required this.borderRadiusLarge,
    required this.cardElevation,
  });

  final double paddingSmall;
  final double paddingMedium;
  final double paddingLarge;
  final double borderRadiusSmall;
  final double borderRadiusMedium;
  final double borderRadiusLarge;
  final double cardElevation;

  static const fallback = AppDesignTokens(
    paddingSmall: 8,
    paddingMedium: 16,
    paddingLarge: 24,
    borderRadiusSmall: 4,
    borderRadiusMedium: 12,
    borderRadiusLarge: 24,
    cardElevation: 0,
  );

  @override
  ThemeExtension<AppDesignTokens> copyWith({
    double? paddingSmall,
    double? paddingMedium,
    double? paddingLarge,
    double? borderRadiusSmall,
    double? borderRadiusMedium,
    double? borderRadiusLarge,
    double? cardElevation,
  }) {
    return AppDesignTokens(
      paddingSmall: paddingSmall ?? this.paddingSmall,
      paddingMedium: paddingMedium ?? this.paddingMedium,
      paddingLarge: paddingLarge ?? this.paddingLarge,
      borderRadiusSmall: borderRadiusSmall ?? this.borderRadiusSmall,
      borderRadiusMedium: borderRadiusMedium ?? this.borderRadiusMedium,
      borderRadiusLarge: borderRadiusLarge ?? this.borderRadiusLarge,
      cardElevation: cardElevation ?? this.cardElevation,
    );
  }

  @override
  ThemeExtension<AppDesignTokens> lerp(
    covariant ThemeExtension<AppDesignTokens>? other,
    double t,
  ) {
    if (other is! AppDesignTokens) return this;
    return AppDesignTokens(
      paddingSmall: lerpDouble(paddingSmall, other.paddingSmall, t)!,
      paddingMedium: lerpDouble(paddingMedium, other.paddingMedium, t)!,
      paddingLarge: lerpDouble(paddingLarge, other.paddingLarge, t)!,
      borderRadiusSmall:
          lerpDouble(borderRadiusSmall, other.borderRadiusSmall, t)!,
      borderRadiusMedium:
          lerpDouble(borderRadiusMedium, other.borderRadiusMedium, t)!,
      borderRadiusLarge:
          lerpDouble(borderRadiusLarge, other.borderRadiusLarge, t)!,
      cardElevation: lerpDouble(cardElevation, other.cardElevation, t)!,
    );
  }

  static double? lerpDouble(double? a, double? b, double t) {
    if (a == null && b == null) return null;
    a ??= 0.0;
    b ??= 0.0;
    return a + (b - a) * t;
  }
  }

ThemeData _buildTheme(
    ColorScheme colorScheme, AppColorsExtension customColors) {
  final textTheme = buildTextTheme();

  return ThemeData(
    useMaterial3: true,
    primaryColor: colorScheme.primary,
    colorScheme: colorScheme,
    textTheme: textTheme,
    extensions: [
      customColors,
      AppDesignTokens.fallback,
    ],

    // --- Basic Elements ---
    scaffoldBackgroundColor: colorScheme.surface,
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    iconTheme: IconThemeData(
      color: colorScheme.onSurface,
      size: 24,
    ),

    // --- Widget Themes ---

    // App Bar Theme
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
    ),
    ),

    // Button Themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        minimumSize: const Size(88, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ).copyWith(
        elevation: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return 2;
          return 0;
        }),
    ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(88, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(88, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: colorScheme.outline, width: 1.5),
    ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(88, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    ),

    // Card Theme
    cardTheme: CardThemeData(
      clipBehavior: Clip.antiAlias,
      elevation: AppDesignTokens.fallback.cardElevation,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
    ),
      color: colorScheme.surfaceContainerLowest,
    ),

    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),

        borderSide: BorderSide(color: colorScheme.outline),
    ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline),
    ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
    ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.error),
    ),
      floatingLabelStyle: TextStyle(color: colorScheme.primary),
      labelStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
      hintStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
    ),

    // Navigation Bar Theme
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.secondaryContainer,
      elevation: 8,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      height: 80,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return textTheme.labelSmall?.copyWith(
              color: colorScheme.primary, fontWeight: FontWeight.bold);
        }
        return textTheme.labelSmall
            ?.copyWith(color: colorScheme.onSurfaceVariant);
      }),
    ),

    // Navigation Rail Theme
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.secondaryContainer,
      labelType: NavigationRailLabelType.all,
      unselectedLabelTextStyle:
          textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
      selectedLabelTextStyle: textTheme.labelSmall
          ?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
    ),

    // Tab Bar Theme
    tabBarTheme: TabBarThemeData(
      labelColor: colorScheme.primary,
      unselectedLabelColor: colorScheme.onSurfaceVariant,
      indicatorColor: colorScheme.primary,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      unselectedLabelStyle: textTheme.titleSmall,
    ),

    // Floating Action Button Theme
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimaryContainer,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    // Chip Theme
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(color: colorScheme.outlineVariant),
      backgroundColor: colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelStyle: textTheme.labelMedium,
    ),

    // List Tile Theme
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      visualDensity: VisualDensity.comfortable,
      titleTextStyle:
          textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      subtitleTextStyle:
          textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
    ),

    // Checkbox Theme
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),

    // Switch Theme
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colorScheme.primary;
        return colorScheme.outline;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colorScheme.primaryContainer;
        }
        return colorScheme.surfaceContainerHighest;
      }),
    ),

    // SnackBar Theme
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle:
          textTheme.bodyMedium?.copyWith(color: colorScheme.onInverseSurface),
    ),

    // Dialog Theme
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: colorScheme.surface,
      titleTextStyle:
          textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      contentTextStyle: textTheme.bodyMedium,
    ),

    // Bottom Sheet Theme
    bottomSheetTheme: const BottomSheetThemeData(
      showDragHandle: true,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
    ),
    ),
    ),

    // Search Bar Theme
    searchBarTheme: SearchBarThemeData(
      elevation: WidgetStateProperty.all(0),
      backgroundColor: WidgetStateProperty.all(colorScheme.surfaceContainerLow),
      shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
      padding:
          WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16)),
      hintStyle: WidgetStateProperty.all(
          textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
    ),

    // Badge Theme
    badgeTheme: BadgeThemeData(
      backgroundColor: colorScheme.error,
      textColor: colorScheme.onError,
      textStyle: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
    ),

    // Segmented Button Theme
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: colorScheme.secondaryContainer,
        selectedForegroundColor: colorScheme.onSecondaryContainer,
        side: BorderSide(color: colorScheme.outline),
    ),
    ),

    // Tooltip Theme
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
    ),
      textStyle:
          textTheme.labelSmall?.copyWith(color: colorScheme.onInverseSurface),
    ),
  );
  }

/// Esquema claro explícito com os tokens do `tailwind.config` do protótipo (D2).
const ColorScheme appLightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF006B2C),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFF00873A),
  onPrimaryContainer: Color(0xFFF7FFF2),
  primaryFixed: Color(0xFF7FFC97),
  primaryFixedDim: Color(0xFF62DF7D),
  onPrimaryFixed: Color(0xFF002109),
  onPrimaryFixedVariant: Color(0xFF005320),
  secondary: Color(0xFF565E74),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFDAE2FD),
  onSecondaryContainer: Color(0xFF5C647A),
  secondaryFixed: Color(0xFFDAE2FD),
  secondaryFixedDim: Color(0xFFBEC6E0),
  onSecondaryFixed: Color(0xFF131B2E),
  onSecondaryFixedVariant: Color(0xFF3F465C),
  tertiary: Color(0xFF755800),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFF936F00),
  onTertiaryContainer: Color(0xFFFFFBFF),
  tertiaryFixed: Color(0xFFFFDF9A),
  tertiaryFixedDim: Color(0xFFF7BE1D),
  onTertiaryFixed: Color(0xFF251A00),
  onTertiaryFixedVariant: Color(0xFF5A4300),
  error: Color(0xFFBA1A1A),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFFDAD6),
  onErrorContainer: Color(0xFF93000A),
  surface: Color(0xFFF7F9FB),
  onSurface: Color(0xFF191C1E),
  onSurfaceVariant: Color(0xFF3E4A3D),
  surfaceDim: Color(0xFFD8DADC),
  surfaceBright: Color(0xFFF7F9FB),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFF2F4F6),
  surfaceContainer: Color(0xFFECEEF0),
  surfaceContainerHigh: Color(0xFFE6E8EA),
  surfaceContainerHighest: Color(0xFFE0E3E5),
  outline: Color(0xFF6E7B6C),
  outlineVariant: Color(0xFFBDCABA),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFF2D3133),
  onInverseSurface: Color(0xFFEFF1F3),
  inversePrimary: Color(0xFF62DF7D),
  surfaceTint: Color(0xFF006E2D),
);

/// Esquema escuro: tons gerados pelo seed e sobrescritos pelos tokens que o
/// protótipo já define (tabela tonal do Material 3, D2).
final ColorScheme appDarkColorScheme = ColorScheme.fromSeed(
  seedColor: const Color(0xFF006B2C),
  brightness: Brightness.dark,
).copyWith(
  primary: const Color(0xFF62DF7D),
  primaryContainer: const Color(0xFF005320),
  onPrimaryContainer: const Color(0xFF7FFC97),
  primaryFixed: const Color(0xFF7FFC97),
  primaryFixedDim: const Color(0xFF62DF7D),
  onPrimaryFixed: const Color(0xFF002109),
  onPrimaryFixedVariant: const Color(0xFF005320),
  secondary: const Color(0xFFBEC6E0),
  secondaryContainer: const Color(0xFF3F465C),
  onSecondaryContainer: const Color(0xFFDAE2FD),
  tertiary: const Color(0xFFF7BE1D),
  tertiaryContainer: const Color(0xFF5A4300),
  onTertiaryContainer: const Color(0xFFFFDF9A),
  tertiaryFixed: const Color(0xFFFFDF9A),
  tertiaryFixedDim: const Color(0xFFF7BE1D),
  onTertiaryFixed: const Color(0xFF251A00),
  onTertiaryFixedVariant: const Color(0xFF5A4300),
  error: const Color(0xFFFFB4AB),
  onError: const Color(0xFF690005),
  errorContainer: const Color(0xFF93000A),
  onErrorContainer: const Color(0xFFFFDAD6),
  onSurface: const Color(0xFFE0E3E5),
  inverseSurface: const Color(0xFFE0E3E5),
  onInverseSurface: const Color(0xFF2D3133),
  inversePrimary: const Color(0xFF006B2C),
);

/// O parâmetro [primaryColorHex] é mantido por compatibilidade e ignorado: as
/// cores vêm de [appLightColorScheme].
ThemeData buildLightTheme({String primaryColorHex = ''}) =>
    _buildTheme(appLightColorScheme, AppPalettes.light);

/// O parâmetro [primaryColorHex] é mantido por compatibilidade e ignorado: as
/// cores vêm de [appDarkColorScheme].
ThemeData buildDarkTheme({String primaryColorHex = ''}) =>
    _buildTheme(appDarkColorScheme, AppPalettes.dark);

CupertinoThemeData buildCupertinoTheme({required String primaryColorHex}) {
  final seed =
      _colorFromHex(primaryColorHex.isNotEmpty ? primaryColorHex : '#007AFF');

  return CupertinoThemeData(
    applyThemeToAll: true,
    primaryColor: seed,
    primaryContrastingColor: CupertinoColors.white,
    brightness: null, // Allow system-wide dark mode support
    scaffoldBackgroundColor: CupertinoColors.systemBackground,
    barBackgroundColor: CupertinoColors.systemGrey6,
    textTheme: CupertinoTextThemeData(
      primaryColor: seed,
      textStyle: const TextStyle(
        
        fontSize: 17,
        letterSpacing: -0.41,
    ),
      actionTextStyle: TextStyle(
        
        color: seed,
        fontSize: 17,
        fontWeight: FontWeight.w400,
    ),
      navTitleTextStyle: const TextStyle(
        
        fontWeight: FontWeight.w600,
        fontSize: 17,
        letterSpacing: -0.41,
    ),
      navLargeTitleTextStyle: const TextStyle(
        
        fontWeight: FontWeight.bold,
        fontSize: 34,
        letterSpacing: 0.41,
    ),
      tabLabelTextStyle: const TextStyle(
        
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.24,
    ),
      pickerTextStyle: const TextStyle(
        
        fontSize: 21,
        letterSpacing: -0.41,
    ),
      dateTimePickerTextStyle: const TextStyle(
        
        fontSize: 21,
        letterSpacing: -0.41,
    ),
    ),
  );
  }

