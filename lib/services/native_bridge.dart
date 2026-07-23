import 'package:flutter/services.dart';

/// M7 — Bridge Flutter ↔ native .so via MethodChannel.
///
/// Native lib chain:
///   memek.so ← aegis.so + cipher.so + vault.so
///
/// Semua call ke sini defensif: kalau plugin belum ready (mis. platform
/// non-Android saat dev), fallback return aman (integrity=true untuk
/// menghindari brick di emulator, premium=false).
class NativeBridge {
  NativeBridge._();
  static const _channel = MethodChannel('com.claudememek.app/native');

  /// True = APK signature match expected. False = tampered / re-signed.
  /// Di dev-mode (EXPECTED_SIG_SHA256 kosong) native selalu return true.
  static Future<bool> integrityCheck() async {
    try {
      final ok = await _channel.invokeMethod<bool>('integrityCheck');
      return ok ?? false;
    } on MissingPluginException {
      return true; // non-Android / unit test
    } catch (_) {
      return false;
    }
  }

  /// Verifikasi token premium yang di-issue backend/local streak service.
  static Future<bool> verifyPremium({
    required String token,
    required int streakDays,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('verifyPremium', {
        'token': token,
        'streakDays': streakDays,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<String> encryptField(String plain) async {
    try {
      final s = await _channel.invokeMethod<String>('encryptField', {'plain': plain});
      return s ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<String> decryptField(String cipher) async {
    try {
      final s = await _channel.invokeMethod<String>('decryptField', {'cipher': cipher});
      return s ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Debug helper — SHA-256 signing cert saat runtime (uppercase hex).
  static Future<String> currentSignature() async {
    try {
      final s = await _channel.invokeMethod<String>('currentSignature');
      return s ?? '';
    } catch (_) {
      return '';
    }
  }

  /// M22 — Ambil CSV daftar API key AI dari `keychain.so` (XOR-obfuscated
  /// saat build). Kalau kosong → caller wajib fallback ke `--dart-define`.
  /// Aman di semua platform: MissingPluginException → ''.
  static Future<String> getApiKeys() async {
    try {
      final s = await _channel.invokeMethod<String>('getApiKeys');
      return s ?? '';
    } on MissingPluginException {
      return '';
    } catch (_) {
      return '';
    }
  }


  /// M32 — Ambil XOR key (0..255) yang dipakai untuk deobfuscate file
  /// dataset (`.jsonlx` / `.mdx`) yang ter-bundle di `assets/dataset/`.
  /// Default fallback 0xA7 kalau plugin belum ready (dev / unit test).
  static Future<int> getDatasetKey() async {
    try {
      final v = await _channel.invokeMethod<int>('getDatasetKey');
      return (v ?? 0xA7) & 0xFF;
    } on MissingPluginException {
      return 0xA7;
    } catch (_) {
      return 0xA7;
    }
  }

  /// M33 — Native runtime detector bitmask.
  /// bit 0 debugger, bit 1 instrumentation, bit 2 root, bit 3 emulator.
  static Future<int> sentinelProbe() async {
    try {
      return await _channel.invokeMethod<int>('sentinelProbe') ?? 0;
    } on MissingPluginException {
      return 0;
    } catch (_) {
      return 0x07; // fail closed when the Android channel exists but JNI fails
    }
  }

  static Future<bool> isRuntimeClean() async {
    final flags = await sentinelProbe();
    return (flags & 0x07) == 0;
  }

}
