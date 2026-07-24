import 'package:flutter/material.dart';

/// KiKai — screenshot-accurate warm minimal tokens.
///
/// Referensi visual: off-white canvas, kartu putih rounded besar, garis
/// tipis hangat, aksen ink hitam, ikon abu netral, dan danger merah lembut.
class AppColors {
  AppColors._();

  // ── Ink / Brand ─────────────────────────────────────────────────
  static const Color primary = Color(0xFF101010);
  static const Color primaryDeep = Color(0xFF050505);
  static const Color accent = Color(0xFF101010);
  static const Color accentDeep = Color(0xFF050505);

  // ── Screenshot surfaces ─────────────────────────────────────────
  static const Color background = Color(0xFFF7F5F0);
  static const Color surface = Color(0xFFFFFEFB);
  static const Color surfaceElevated = Color(0xFFFFFEFB);
  static const Color surfaceHigh = Color(0xFFEAE7DF);
  static const Color softChip = Color(0xFFDFDED9);
  static const Color iconTile = Color(0xFFDDDDDD);
  static const Color divider = Color(0xFFE3DFD7);

  // ── Text ───────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF151515);
  static const Color textSecondary = Color(0xFF625F58);
  static const Color textMuted = Color(0xFFA19D94);

  // ── States ─────────────────────────────────────────────────────
  static const Color success = Color(0xFF101010);
  static const Color warning = Color(0xFF2F2F2F);
  static const Color danger = Color(0xFFA91616);
  static const Color dangerSurface = Color(0xFFF2E4E0);
  static const Color dangerTile = Color(0xFFE9C7C2);

  // ── Bubble / nav ───────────────────────────────────────────────
  static const Color bubbleUser = Color(0xFF101010);
  static const Color bubbleUserDeep = Color(0xFF050505);
  static const Color bubbleAssistant = Color(0xFFFFFEFB);
  static const Color online = Color(0xFF101010);
  static const Color navInactive = Color(0xFFA9A59B);

  // ── Compatible legacy gradients (solid ink) ────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF101010), Color(0xFF050505)],
  );

  static const LinearGradient userBubbleGradient = LinearGradient(
    colors: [Color(0xFF101010), Color(0xFF050505)],
  );

  static const LinearGradient avatarGradient = LinearGradient(
    colors: [Color(0xFF101010), Color(0xFF050505)],
  );
}
