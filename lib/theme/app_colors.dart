import 'package:flutter/material.dart';

/// Палитра приложения — светлая и тёмная темы.
class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════════════
  //  СВЕТЛАЯ ТЕМА
  // ═══════════════════════════════════════════════════════════

  static const Color lightBackground = Color(0xFFF8F9FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF0F0F5);
  static const Color lightPrimary = Color(0xFF6C5CE7);
  static const Color lightPrimaryDark = Color(0xFF5A4BC7);
  static const Color lightSecondary = Color(0xFFFD79A8);
  static const Color lightText = Color(0xFF1A1A2E);
  static const Color lightTextSecondary = Color(0xFF6B6B7B);
  static const Color lightDivider = Color(0xFFE5E5EC);
  static const Color lightSuccess = Color(0xFF00B894);
  static const Color lightWarning = Color(0xFFFDCB6E);
  static const Color lightError = Color(0xFFE74C3C);

  // ═══════════════════════════════════════════════════════════
  //  ТЁМНАЯ ТЕМА
  // ═══════════════════════════════════════════════════════════

  static const Color darkBackground = Color(0xFF0F0F1E);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkSurfaceVariant = Color(0xFF252540);
  static const Color darkPrimary = Color(0xFFA29BFE);
  static const Color darkPrimaryDark = Color(0xFF8B82E0);
  static const Color darkSecondary = Color(0xFFFD79A8);
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB0B0C0);
  static const Color darkDivider = Color(0xFF2E2E4A);
  static const Color darkSuccess = Color(0xFF55EFC4);
  static const Color darkWarning = Color(0xFFFFD93D);
  static const Color darkError = Color(0xFFFF7675);

  // ═══════════════════════════════════════════════════════════
  //  ЦВЕТА ГРУПП МЫШЦ (для акцентов)
  // ═══════════════════════════════════════════════════════════

  static const Color muscleGlutes = Color(0xFFE84393);
  static const Color muscleAbs = Color(0xFFFDCB6E);
  static const Color muscleArms = Color(0xFF74B9FF);
  static const Color muscleLegs = Color(0xFF00B894);
  static const Color muscleBack = Color(0xFFA29BFE);
  static const Color muscleChest = Color(0xFFFD79A8);
  static const Color muscleCardio = Color(0xFFE17055);
  static const Color muscleYoga = Color(0xFF81ECEC);

  // ═══════════════════════════════════════════════════════════
  //  ГРАДИЕНТЫ (для карточек)
  // ═══════════════════════════════════════════════════════════

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00B894), Color(0xFF55EFC4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFFD79A8), Color(0xFFFDCB6E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}