import '../core/constants/app_config.dart';
import 'native_bridge.dart';

/// Ambil API key & base URL dari `--dart-define` (di-inject GitHub Actions
/// saat build). JANGAN pernah `print` field-nya.
///
/// ## M4 — Rotasi multi-key
///
/// Owner punya banyak API key (20+) dari kie.ai. Untuk supaya ketika 1 key
/// habis quota / rate-limit / expired, request otomatis retry ke key
/// berikutnya, `ApiKeyService` menerima **daftar key** via:
///
/// ```
/// flutter run \
///   --dart-define=AI_API_KEYS=sk-a,sk-b,sk-c,sk-d
/// ```
///
/// Dipisah koma (`,`) atau titik-koma (`;`). Spasi & entry kosong di-strip.
/// Backward-compat: kalau `AI_API_KEYS` kosong, fallback ke single
/// `AI_API_KEY` (lama).
///
/// Rotasi dikendalikan runtime oleh [markKeyExhausted] — kalau
/// `AiClientService` dapat 401/403/429, dia panggil method ini untuk
/// pindah ke key berikutnya, sampai semua habis (baru raise error final).
class ApiKeyService {
  ApiKeyService._();

  // ── Build-time defines ──────────────────────────────────────────────

  static const String _rawKeys = String.fromEnvironment('AI_API_KEYS');
  static const String _singleKey = String.fromEnvironment('AI_API_KEY');

  static const String baseUrl = String.fromEnvironment(
    'AI_API_BASE_URL',
    defaultValue: AppConfig.defaultApiBaseUrl,
  );

  static const String defaultModel = String.fromEnvironment(
    'AI_DEFAULT_MODEL',
    defaultValue: AppConfig.defaultModelId,
  );

  // ── State runtime rotasi ────────────────────────────────────────────

  static List<String>? _cachedKeys;
  static int _cursor = 0;
  static final Set<int> _exhausted = <int>{};

  /// Semua key yang di-inject saat build. Urutan sesuai input owner.
  /// **M22** — Init async: coba ambil key dari native `keychain.so`
  /// (XOR-obfuscated). Kalau ada → override cache, `--dart-define`
  /// jadi fallback. Panggil sekali dari `main.dart` sebelum runApp.
  static Future<void> init() async {
    if (_cachedKeys != null && _cachedKeys!.isNotEmpty) return;
    try {
      final csv = await NativeBridge.getApiKeys();
      if (csv.isEmpty) return; // fallback ke --dart-define
      final list = csv
          .split(RegExp(r'[,;]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
      if (list.isNotEmpty) _cachedKeys = list;
    } catch (_) {
      // no-op — biar getter `keys` fallback baca --dart-define.
    }
  }

  static List<String> get keys {
    final cached = _cachedKeys;
    if (cached != null) return cached;

    final raw = _rawKeys.isNotEmpty ? _rawKeys : _singleKey;
    final list = raw
        .split(RegExp(r'[,;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    _cachedKeys = list;
    return list;
  }

  /// True kalau minimal ada satu key aktif.
  static bool get isConfigured => activeKey.isNotEmpty;

  /// Total key valid yang di-inject.
  static int get totalKeys => keys.length;

  /// Jumlah key yang masih "sehat" (belum di-mark exhausted).
  static int get liveKeys => totalKeys - _exhausted.length;

  /// Key yang sedang aktif dipakai. Kosong ("") kalau habis semua.
  static String get activeKey {
    final all = keys;
    if (all.isEmpty) return '';
    // Kalau cursor kena key exhausted, geser ke key sehat berikutnya.
    for (int i = 0; i < all.length; i++) {
      final idx = (_cursor + i) % all.length;
      if (!_exhausted.contains(idx)) {
        _cursor = idx;
        return all[idx];
      }
    }
    return ''; // semua habis
  }

  /// Alias lama — masih dipakai UI (misal maskedKey di About).
  static String get apiKey => activeKey;

  /// Tandai key yang barusan dipakai (`activeKey` saat request gagal
  /// otentikasi/quota) sebagai habis, lalu geser cursor. Return `true`
  /// kalau masih ada key sehat lain untuk di-retry.
  static bool markKeyExhausted() {
    final all = keys;
    if (all.isEmpty) return false;
    _exhausted.add(_cursor);
    // cari key sehat berikutnya
    for (int i = 1; i <= all.length; i++) {
      final idx = (_cursor + i) % all.length;
      if (!_exhausted.contains(idx)) {
        _cursor = idx;
        return true;
      }
    }
    return false;
  }

  /// Reset state exhausted (mis. dipanggil dari Settings "reset key
  /// rotation"). Tidak dipakai otomatis — biarkan owner yang memutuskan
  /// kapan kasih kesempatan ulang.
  static void resetRotation() {
    _exhausted.clear();
    _cursor = 0;
  }

  /// Info aman ditampilkan di UI Settings (About). TIDAK expose full key.
  static String get maskedKey {
    final k = activeKey;
    if (k.isEmpty) return '(belum di-set)';
    if (k.length <= 8) return '••••';
    return '${k.substring(0, 4)}••••${k.substring(k.length - 4)}';
  }

  /// Ringkasan status rotasi untuk banner/About.
  static String get rotationSummary {
    final total = totalKeys;
    if (total == 0) return 'Tidak ada API key.';
    if (total == 1) return '1 API key aktif.';
    return '$liveKeys/$total API key aktif (rotasi otomatis).';
  }
}
