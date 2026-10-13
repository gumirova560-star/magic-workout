import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Стили текста — единые для всего приложения.
class AppTextStyles {
  AppTextStyles._();

  // ═══════════════════════════════════════════════════════════
  //  ЗАГОЛОВКИ (Manrope — жирный, современный)
  // ═══════════════════════════════════════════════════════════

  static TextStyle h1 = GoogleFonts.manrope(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );

  static TextStyle h2 = GoogleFonts.manrope(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static TextStyle h3 = GoogleFonts.manrope(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  static TextStyle h4 = GoogleFonts.manrope(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  // ═══════════════════════════════════════════════════════════
  //  ОСНОВНОЙ ТЕКСТ (Inter — читаемый)
  // ═══════════════════════════════════════════════════════════

  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static TextStyle bodyBold = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  // ═══════════════════════════════════════════════════════════
  //  АКЦЕНТЫ (Unbounded — для цифр)
  // ═══════════════════════════════════════════════════════════

  static TextStyle statBig = GoogleFonts.unbounded(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
  );

  static TextStyle statMedium = GoogleFonts.unbounded(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
  );

  // ═══════════════════════════════════════════════════════════
  //  КНОПКИ
  // ═══════════════════════════════════════════════════════════

  static TextStyle button = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static TextStyle buttonSmall = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );
}