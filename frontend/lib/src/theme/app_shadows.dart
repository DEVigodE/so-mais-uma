import 'package:flutter/material.dart';

/// Predefined box shadows aligned with Material 3 elevation tiers.
///
/// Usage:
/// ```dart
/// Container(
///   decoration: BoxDecoration(
///     boxShadow: AppShadows.card,
///   ),
/// )
/// ```
abstract final class AppShadows {
  AppShadows._();

  /// No shadow — flat, tonal surface (elevation 0).
  static const List<BoxShadow> none = [];

  /// Minimal shadow — barely lifted surfaces (elevation 1).
  /// Use for: toggle surfaces, filled cards on white background.
  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x0D000000), // 5% black
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  /// Card shadow — clearly elevated content (elevation 2–3).
  /// Use for: cards, list items that are tappable, floating elements.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x14000000), // 8% black
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x0A000000), // 4% black
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  /// Elevated shadow — significantly raised surface (elevation 6–8).
  /// Use for: FABs, dropdown menus, tooltips.
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x1F000000), // 12% black
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Color(0x0F000000), // 6% black
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  /// Modal shadow — overlay surfaces, dialogs, bottom sheets (elevation 12+).
  /// Use for: dialogs, modals, side sheets.
  static const List<BoxShadow> modal = [
    BoxShadow(
      color: Color(0x29000000), // 16% black
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
    BoxShadow(
      color: Color(0x14000000), // 8% black
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  /// Barra superior fixa (`shadow-[0_1px_8px_rgba(0,0,0,0.04)]`).
  static const List<BoxShadow> topBar = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 1)),
  ];

  /// Bottom-nav (`shadow-[0_-2px_12px_rgba(0,0,0,0.05)]`).
  static const List<BoxShadow> bottomBar = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, -2)),
  ];
}
