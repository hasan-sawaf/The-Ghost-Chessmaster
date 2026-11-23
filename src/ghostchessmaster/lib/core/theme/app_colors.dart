import 'package:flutter/material.dart';

/// Chess-inspired color palette for GhostchessMaster
class AppColors {
  // Brand / Theme Colors
  static const Color primaryGold = Color(0xFFD4AF37);      // Gold accent for Dark Theme
  static const Color primaryAmber = Color(0xFFC5832B);
  static const Color primaryMahogany = Color(0xFF3E2723);  // Rich Dark Chess Mahogany / Walnut for Light Theme!
  static const Color primaryDarkMahogany = Color(0xFF2C1B18);

  // --- Light Theme Colors (Dark Chess Mahogany Palette - No Bright Yellow!) ---
  static const Color lightBackground = Color(0xFFF5F2ED);  // Warm Ivory Parchment
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFEBE7DF);        // Classy Warm Parchment Card
  static const Color lightPrimary = Color(0xFF3E2723);     // Dark Espresso Walnut Primary
  static const Color lightSecondary = Color(0xFF5D4037);   // Rich Chess Mahogany Secondary
  static const Color lightTextPrimary = Color(0xFF1E1E24);
  static const Color lightTextSecondary = Color(0xFF6E6E78);
  static const Color lightBorder = Color(0xFFD7D2C8);

  // Chess Board Light Theme Accents
  static const Color lightSquareLight = Color(0xFFF0D9B5);
  static const Color lightSquareDark = Color(0xFFB58863);

  // --- Dark Theme Colors ---
  static const Color darkBackground = Color(0xFF121319);
  static const Color darkSurface = Color(0xFF1A1C24);
  static const Color darkCard = Color(0xFF242733);
  static const Color darkTextPrimary = Color(0xFFF4F4F6);
  static const Color darkTextSecondary = Color(0xFF9E9EA8);
  static const Color darkBorder = Color(0xFF2E3242);

  // Chess Board Dark Theme Accents
  static const Color darkSquareLight = Color(0xFF8CA2AD);
  static const Color darkSquareDark = Color(0xFF4B7399);

  // System Feedback Colors
  static const Color success = Color(0xFF2E7D32);
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFED6C02);
}
