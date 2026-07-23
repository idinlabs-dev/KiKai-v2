import 'package:flutter/material.dart';

/// KiKai — Design tokens (M43 refresh).
///
/// Palette dipertahankan cream + ink (identity brand), tapi tone di-tuning:
/// - surface layers dibuat lebih berlapis (background, surface, surfaceHigh)
/// - accent tetap solid ink hitam
/// - shadow token baru untuk kartu / bottom-sheet
///
/// SEMUA warna wajib diambil dari sini. Jangan hardcode `Color(0xFF...)` di
/// screen/widget.
class AppColors {
  AppColors._();

  // ── Ink (aksen utama = hitam) ──────────────────────────────────
  static const Color primary = Color(0xFF0F0F10);      // near-black
  static const Color primaryDeep = Color(0xFF000000);
  static const Color accent = Color(0xFF0F0F10);
  static const Color accentDeep = Color(0xFF000000);

  // ── Surface (cream, layered) ───────────────────────────────────
  static const Color background = Color(0xFFF6F4EF);    // cream halus
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceHigh = Color(0xFFEEECE5);   // chip / track
  static const Color surfaceSoft = Color(0xFFFAF8F3);   // secondary bg
  static const Color divider = Color(0xFFE5E2DA);

  // ── Text ───────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F0F10);
  static const Color textSecondary = Color(0xFF5A5852);
  static const Color textMuted = Color(0xFF9C988E);

  // ── States (monokrom) ─────────────────────────────────────────
  static const Color success = Color(0xFF14532D);
  static const Color warning = Color(0xFF7C2D12);
  static const Color danger = Color(0xFF991B1B);

  // ── Bubble ─────────────────────────────────────────────────────
  static const Color bubbleUser = Color(0xFF0F0F10);
  static const Color bubbleUserDeep = Color(0xFF0F0F10);
  static const Color bubbleAssistant = Color(0xFFFFFFFF);

  // ── Bottom nav ─────────────────────────────────────────────────
  static const Color online = Color(0xFF0F0F10);
  static const Color navInactive = Color(0xFFB1ADA2);

  // ── Shadow token ───────────────────────────────────────────────
  static const Color shadowSoft = Color(0x14000000); // 8% black
  static const Color shadowStrong = Color(0x22000000);

  // ── "Gradient" (solid — no gradasi) ────────────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF0F0F10), Color(0xFF0F0F10)],
  );

  static const LinearGradient userBubbleGradient = LinearGradient(
    colors: [Color(0xFF0F0F10), Color(0xFF0F0F10)],
  );

  static const LinearGradient avatarGradient = LinearGradient(
    colors: [Color(0xFF0F0F10), Color(0xFF0F0F10)],
  );
}
