import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const Color primary = Color(0xFF1A1A1A); // Near black — text & key actions
  static const Color primaryGreen = Color(0xFF2D6A4F); // Deep forest green — brand
  static const Color accentGreen = Color(0xFF52B788); // Lighter green — highlights
  static const Color softGreen = Color(0xFFD8F3DC); // Very light green — backgrounds/chips

  // Neutrals
  static const Color background = Color(0xFFFAFAFA); // Off white — page background
  static const Color surface = Color(0xFFFFFFFF); // Pure white — cards/panels
  static const Color surfaceAlt = Color(0xFFF5F5F5); // Light grey — secondary surfaces
  static const Color border = Color(0xFFE8E8E8); // Subtle border color

  // Text
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textTertiary = Color(0xFFAAAAAA);

  // Semantic
  static const Color success = Color(0xFF2D6A4F);
  static const Color warning = Color(0xFFF4A261); // Warm amber — not harsh yellow
  static const Color error = Color(0xFFE63946); // Clean red
  static const Color info = Color(0xFF457B9D); // Muted blue

  // Backwards-compatible aliases used throughout the app.
  static const Color backgroundWhite = background;
  static const Color textDark = textPrimary;
  static const Color textGrey = textSecondary;
  static const Color errorRed = error;
  static const Color successGreen = success;
  static const Color amber = warning;
  static const Color lightGreen = accentGreen;
  static const Color lightAmber = Color(0xFFFFF3E0); // Soft tint for legacy usage
}
