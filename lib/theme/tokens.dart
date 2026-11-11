import 'package:flutter/material.dart';

/// Colores de Lapso. Todos los pares texto/fondo usados en la app cumplen
/// contraste 4.5:1; los bordes de controles cumplen 3:1 (WCAG 2.2 AA).
abstract final class LapsoColors {
  static const Color navy = Color(0xFF071D53);
  static const Color night = Color(0xFF040E2C);
  static const Color primary = Color(0xFF0758EE);
  static const Color primaryDark = Color(0xFF0647C4);
  static const Color primarySoft = Color(0xFFE6EFFE);
  static const Color cyan = Color(0xFF05D5F4);

  static const Color ground = Color(0xFFF3F7FD);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color keyFill = Color(0xFFF0F5FC);
  static const Color line = Color(0xFFDCE6F5);
  static const Color lineSoft = Color(0xFFE8EEF8);

  /// Borde de campos, opciones e indicadores vacíos (3.1:1 sobre blanco).
  static const Color control = Color(0xFF6F86B2);
  static const Color muted = Color(0xFF4A5D85);

  static const Color onNavyMuted = Color(0xFFA9C3EE);
  static const Color onNavySoft = Color(0xFFC9DAF5);
  static const Color onNavyChip = Color(0x1FFFFFFF);
  static const Color onNavyLine = Color(0x24FFFFFF);

  static const Color good = Color(0xFF0B6B47);
  static const Color goodIcon = Color(0xFF0B7A50);
  static const Color goodBg = Color(0xFFE2F6EC);
  static const Color goodDot = Color(0xFF3BE29B);

  static const Color warn = Color(0xFF8A5300);
  static const Color warnText = Color(0xFF6B4100);
  static const Color warnBg = Color(0xFFFFF1D6);
  static const Color amber = Color(0xFFFFB547);

  static const Color bad = Color(0xFFB0213D);
  static const Color badBg = Color(0xFFFFEBEE);

  static const Color infoText = Color(0xFF0A2D73);
  static const Color placeholderBg = Color(0xFFD9E3F2);
  static const Color placeholderLine = Color(0xFFC2D0E6);
  static const Color scrim = Color(0x8C040E2C);
}

abstract final class LapsoRadius {
  static const double card = 20;
  static const double hero = 24;
  static const double button = 16;
  static const double field = 14;
  static const double sheet = 28;
}

abstract final class LapsoText {
  static const String body = 'Inter';
  static const String display = 'Montserrat';

  static const List<FontFeature> tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// Títulos y cifras grandes (Montserrat 700).
  static TextStyle heading(double size, {Color color = LapsoColors.navy}) {
    return TextStyle(
      fontFamily: display,
      fontWeight: FontWeight.w700,
      fontSize: size,
      height: 1.2,
      letterSpacing: size >= 40 ? -1.2 : -0.4,
      color: color,
      fontFeatures: tabular,
    );
  }

  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: LapsoColors.navy,
  );

  static const TextStyle secondary = TextStyle(
    fontSize: 14,
    height: 1.45,
    color: LapsoColors.muted,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 13,
    height: 1.45,
    color: LapsoColors.muted,
  );

  static const TextStyle section = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    color: LapsoColors.muted,
  );
}
