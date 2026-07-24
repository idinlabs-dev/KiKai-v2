import 'package:flutter/material.dart';

/// KiKai — **Ocean Deep** palette (redesign M46).
///
/// Latar biru-putih tulang lembut, kartu putih bersih, aksen navy dalam
/// dan teal laut. Bukan hitam-putih monokrom, bukan glow/cyberpunk —
/// terasa profesional, tenang, dan berkarakter. Semua nama field lama
/// tetap dipertahankan supaya kode existing tidak perlu diubah.
class AppColors {
  AppColors._();

  // ── Ink / Brand ─────────────────────────────────────────────────
  static const Color primary = Color(0xFF0C2340);      // deep navy
  static const Color primaryDeep = Color(0xFF081729);  // ink navy
  static const Color accent = Color(0xFF2D8A9E);       // teal laut
  static const Color accentDeep = Color(0xFF1A4A6E);   // mid ocean

  // ── Screenshot surfaces ─────────────────────────────────────────
  static const Color background = Color(0xFFEEF2F7);     // bone-blue canvas
  static const Color surface = Color(0xFFFFFFFF);        // card putih bersih
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceHigh = Color(0xFFDCE5F0);    // biru muda soft
  static const Color softChip = Color(0xFFE4ECF5);
  static const Color iconTile = Color(0xFFD5DEEB);
  static const Color divider = Color(0xFFD9E1EC);

  // ── Text ───────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0C1C33);
  static const Color textSecondary = Color(0xFF4A5C73);
  static const Color textMuted = Color(0xFF8996A8);

  // ── States ─────────────────────────────────────────────────────
  static const Color success = Color(0xFF2D8A9E);
  static const Color warning = Color(0xFFB07C3A);
  static const Color danger = Color(0xFFC24A3A);
  static const Color dangerSurface = Color(0xFFF7E6E2);
  static const Color dangerTile = Color(0xFFEDC7BF);

  // ── Bubble / nav ───────────────────────────────────────────────
  static const Color bubbleUser = Color(0xFF0C2340);
  static const Color bubbleUserDeep = Color(0xFF081729);
  static const Color bubbleAssistant = Color(0xFFFFFFFF);
  static const Color online = Color(0xFF2D8A9E);
  static const Color navInactive = Color(0xFF8996A8);

  // ── Ocean gradients (subtle, bukan glow) ───────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0C2340), Color(0xFF1A4A6E)],
  );

  static const LinearGradient userBubbleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0C2340), Color(0xFF15355C)],
  );

  static const LinearGradient avatarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A4A6E), Color(0xFF2D8A9E)],
  );
}
