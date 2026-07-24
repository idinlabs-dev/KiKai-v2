import 'package:flutter/material.dart';

/// KiKai — color tokens (pastel violet, light-first).
///
/// Rebrand: soft pastel lilac/pink background, aksen violet, kartu
/// glass-like putih. TIDAK memakai neon/cyberpunk/glow.
class AppColors {
  AppColors._();

  // ── Brand (violet) ─────────────────────────────────────────────
  static const Color primary = Color(0xFF8B5CF6);
  static const Color primaryDeep = Color(0xFF7C3AED);
  static const Color accent = Color(0xFFEC7FB0);
  static const Color accentDeep = Color(0xFFDB6AA0);

  // ── Surface (pastel sky) ───────────────────────────────────────
  static const Color background = Color(0xFFF6F1FB);      // lilac lembut
  static const Color skyBackground = Color(0xFFEFE7FA);   // lilac lebih pekat
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceHigh = Color(0xFFEDE4FB);
  static const Color divider = Color(0xFFE5DBF3);

  // ── Text ───────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1F1636);
  static const Color textSecondary = Color(0xFF6B6383);
  static const Color textMuted = Color(0xFF9B94B0);

  // ── States ────────────────────────────────────────────────────
  static const Color success = Color(0xFF34C77B);
  static const Color warning = Color(0xFFE8A93A);
  static const Color danger = Color(0xFFE05A6F);

  // ── Bubble ─────────────────────────────────────────────────────
  static const Color bubbleUser = Color(0xFF8B5CF6);
  static const Color bubbleUserDeep = Color(0xFF7C3AED);
  static const Color bubbleAssistant = Color(0xFFFFFFFF);

  // ── Bottom nav ─────────────────────────────────────────────────
  static const Color online = Color(0xFF34C77B);
  static const Color navInactive = Color(0xFFB5AEC7);

  // ── Gradients ─────────────────────────────────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFFEC7FB0)],
  );

  static const LinearGradient userBubbleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9B6DF7), Color(0xFF7C3AED)],
  );

  static const LinearGradient avatarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB48CFA), Color(0xFFEC7FB0)],
  );

  static const LinearGradient skyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF6F1FB), Color(0xFFFCEDF3)],
  );
}
