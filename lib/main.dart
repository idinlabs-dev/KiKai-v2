import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/ads_service.dart';
import 'services/auth_service.dart';
import 'services/firebase_service.dart';
import 'services/kikai_dataset_service.dart';
import 'services/streak_service.dart';
import 'services/tamper_guard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFF5F3EE),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // ── M7 — Anti-tamper gate ────────────────────────────────────────
  // Kalau APK di-rebuild / re-sign oleh pihak lain, native lib deteksi
  // signature mismatch → block boot, redirect ke google.com.
  final integrityOk = await TamperGuard.check();
  if (!integrityOk) {
    runApp(TamperGuard.blockedScreen());
    return;
  }

  // ── AI key lokal sudah dihapus — semua trafik AI lewat proxy Vercel.

  // ── M30 — Load KiKai dataset (persona + identity) untuk system prompt.
  unawaited(KikaiDatasetService.instance.ensureLoaded());

  // ── M7 — Backend init ────────────────────────────────────────────
  await FirebaseService.instance.init();     // Firebase (chat history + streak)
  await AuthService.instance.load();         // Restore session lokal

  // M5 — Preload streak.
  await StreakService.instance.load();

  // M24 — Init AdMob (non-blocking best-effort).
  unawaited(AdsService.instance.init());

  runApp(const KiKaiApp());
}
