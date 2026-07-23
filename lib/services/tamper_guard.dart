import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'native_bridge.dart';

/// M7 — Anti-tamper guard.
///
/// Alur:
/// 1. `TamperGuard.check()` dipanggil di `main()` sebelum `runApp`.
/// 2. Kalau `NativeBridge.integrityCheck()` return false → app *tidak*
///    boot normal, langsung buka `https://idinlabs-dev.github.io/hahahafuckyou/` (placeholder;
///    owner nanti ganti ke landing page redirect) lalu `SystemNavigator.pop`.
/// 3. Kalau true → return, app lanjut normal.
///
/// Native side dev-mode (EXPECTED_SIG_SHA256 kosong) selalu OK → dev tidak
/// terganggu saat `flutter run` lokal.
class TamperGuard {
  TamperGuard._();

  static const String _redirectUrl = 'https://idinlabs-dev.github.io/hahahafuckyou/';

  /// True = clean, boleh lanjut. False = tampered, harus block.
  static Future<bool> check() async {
    final results = await Future.wait<bool>([
      NativeBridge.integrityCheck(),
      NativeBridge.isRuntimeClean(),
    ]);
    return results.every((ok) => ok);
  }

  /// Render layar minimal + auto-redirect ke [_redirectUrl].
  static Widget blockedScreen() {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _BlockedView(url: _redirectUrl),
    );
  }
}

class _BlockedView extends StatefulWidget {
  final String url;
  const _BlockedView({required this.url});

  @override
  State<_BlockedView> createState() => _BlockedViewState();
}

class _BlockedViewState extends State<_BlockedView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _redirect());
  }

  Future<void> _redirect() async {
    final uri = Uri.parse(widget.url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    // Beri jeda sedikit supaya browser sempet open, lalu keluar.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    // Tidak pakai SystemNavigator.pop supaya user tidak balik ke app —
    // biarin tetap di layar redirect kosong.
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0B0B14),
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
