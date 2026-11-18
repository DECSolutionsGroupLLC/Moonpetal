import 'package:flutter/material.dart';

/// Pink palette with dark ink on light pink for readable contrast.
abstract final class MoonpetalColors {
  static const deepPink = Color(0xFF880E4F);
  static const softPink = Color(0xFFFCE4EC);
  static const viewportBackdrop = Color(0xFFF3E0E8);
}

/// The app-wide pink theme. Main body text is at least 16 logical pixels.
final ThemeData moonpetalTheme = _buildTheme();

ThemeData _buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFC2185B),
  ).copyWith(
    surface: const Color(0xFFFFF7FA),
    surfaceContainerHighest: MoonpetalColors.softPink,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.4),
    ),
  );
}
