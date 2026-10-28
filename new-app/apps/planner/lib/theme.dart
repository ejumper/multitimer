import 'package:flutter/material.dart';

/// Bundled font families (registered in pubspec.yaml; local-only assets).
abstract final class AppFonts {
  /// UI text font.
  static const String ui = 'ProLisa';

  /// Timer/number readouts — monospace so digits don't jitter.
  static const String digits = 'MonoLisa';
}

/// v1 color tokens (OUTLINE.md D11).
abstract final class AppColors {
  /// Text/foreground.
  static const Color text = Color(0xFFF2F2F2);

  /// Preset accent swatches (interval/timer colors).
  static const Color magenta = Color(0xFFFF00B1);
  static const Color violet = Color(0xFF4800FF);
  static const Color blue = Color(0xFF0055FF);
  static const Color lightBlue = Color(0xFF00A8FF);
  static const Color green = Color(0xFF00AD6B);
  static const Color lime = Color(0xFFB8FF00);

  /// Semi-transparent dark "card" background — legible over compositor blur.
  /// (black @ ~45%; tunable for legibility.)
  static const Color card = Color(0x73000000);

  /// Dimmed/disabled content.
  static const Color dimmed = Color(0x66F2F2F2);

  /// Hairlines, brackets, outlines.
  static const Color outline = Color(0x40F2F2F2);
}

/// App theme: transparent scaffold over the compositor's blur, dark content.
ThemeData buildPlannerTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    // Fully transparent window background — the compositor supplies blur.
    scaffoldBackgroundColor: const Color(0x00000000),
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.blue,
      secondary: AppColors.lightBlue,
      surface: AppColors.card,
      onSurface: AppColors.text,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
      fontFamily: AppFonts.ui,
    ),
    iconTheme: const IconThemeData(color: AppColors.lightBlue, size: 26),
    splashFactory: InkSparkle.splashFactory,
  );
}
