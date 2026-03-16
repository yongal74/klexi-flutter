import 'package:flutter/material.dart';

/// Klexi 색상 시스템 — Light Theme (design reference v2)
abstract class AppColors {
  // ── Primary Gradient ──────────────────────────────────
  static const Color primary     = Color(0xFF667EEA);  // Purple-Blue
  static const Color primaryDark = Color(0xFF764BA2);  // Deep Purple
  static const Color accent      = Color(0xFFFF8C42);  // Warm Orange

  // ── Background System ─────────────────────────────────
  static const Color bg          = Color(0xFFF2F3F8);  // App background
  static const Color surface     = Color(0xFFFFFFFF);  // Card / Sheet
  static const Color surfaceAlt  = Color(0xFFF7F8FC);  // Subtle alt bg
  static const Color border      = Color(0xFFE8EAF0);  // Divider / border
  static const Color divider     = Color(0xFFEEF0F5);  // Light divider

  // ── Text System ───────────────────────────────────────
  static const Color textPrimary   = Color(0xFF1A1C2E);  // Main text
  static const Color textSecondary = Color(0xFF6B7280);  // Subtitle
  static const Color textMuted     = Color(0xFF9CA3AF);  // Hint / disabled
  static const Color textOnPrimary = Color(0xFFFFFFFF);  // Text on gradient

  // ── State Colors ──────────────────────────────────────
  static const Color success  = Color(0xFF22C55E);
  static const Color error    = Color(0xFFEF4444);
  static const Color warning  = Color(0xFFF59E0B);
  static const Color info     = Color(0xFF3B82F6);
  static const Color streak   = Color(0xFFFF6B35);
  static const Color xpGold   = Color(0xFFFFD700);

  // ── TOPIK Level Colors ────────────────────────────────
  static const Color topik1 = Color(0xFF4CAF50);  // 초록
  static const Color topik2 = Color(0xFF2196F3);  // 파랑
  static const Color topik3 = Color(0xFFFF9800);  // 주황
  static const Color topik4 = Color(0xFF9C27B0);  // 보라
  static const Color topik5 = Color(0xFFF44336);  // 빨강
  static const Color topik6 = Color(0xFF667EEA);  // 브랜드

  static Color topikColor(int level) {
    switch (level) {
      case 1: return topik1;
      case 2: return topik2;
      case 3: return topik3;
      case 4: return topik4;
      case 5: return topik5;
      case 6: return topik6;
      default: return topik1;
    }
  }

  static Color topikBg(int level) => topikColor(level).withOpacity(0.12);

  // ── Gradients ─────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8C42), Color(0xFFFF5E57)],
  );

  static LinearGradient levelGradient(int level) {
    final c = topikColor(level);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [c, c.withOpacity(0.7)],
    );
  }

  // ── Shadow ────────────────────────────────────────────
  static List<BoxShadow> cardShadow = [
    BoxShadow(color: const Color(0xFF667EEA).withOpacity(0.08),
      blurRadius: 16, offset: const Offset(0, 4)),
  ];

  static List<BoxShadow> subtleShadow = [
    BoxShadow(color: Colors.black.withOpacity(0.06),
      blurRadius: 8, offset: const Offset(0, 2)),
  ];
}
