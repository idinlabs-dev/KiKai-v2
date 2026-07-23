/// Konstanta global aplikasi.
class AppConfig {
  AppConfig._();

  /// Nama app yang tampil di UI. (Rebrand total → "KiKai".)
  static const String appName = 'KiKai';
  static const String appTagline = 'Your everyday AI companion';

  /// Version — WAJIB di-bump manual tiap release (sync dengan `pubspec.yaml`).
  static const String appVersion = '0.15.0';
  static const int appBuild = 22;

  /// Default model — model tunggal KiKai (backend nvidia-ultra).
  static const String defaultModelId = 'kikai';

  /// Proxy NVIDIA Nemotron (deploy Vercel `nvidia-backend/`).
  /// API key NVIDIA hidup di env-var Vercel, TIDAK ada di APK.
  /// Bisa di-override saat build via `--dart-define=NVIDIA_BACKEND_URL=...`.
  static const String nvidiaBackendUrl = String.fromEnvironment(
    'NVIDIA_BACKEND_URL',
    defaultValue: 'https://nvidia-api-nine.vercel.app/api/chat',
  );

  /// Base URL backend web tools KiKai (deploy Vercel yg sama dengan
  /// NVIDIA proxy). Endpoint yg dipakai:
  ///   POST {webBackendBase}/read-url  → Jina Reader proxy
  ///   POST {webBackendBase}/vision    → kie.ai gemini-2.5-flash (search + vision)
  static const String webBackendBase = String.fromEnvironment(
    'WEB_BACKEND_BASE',
    defaultValue: 'https://nvidia-api-nine.vercel.app/api',
  );

  /// Batas ukuran attachment default (bytes).
  static const int defaultMaxAttachmentBytes = 1024 * 1024; // 1 MB
  static const int defaultMaxAttachmentsPerMessage = 5;

  /// Context window: jumlah pesan terakhir yang dikirim ke AI.
  static const int contextWindowMessages = 20;
}
