/// Model catalog entry — dipakai model selector & AI client routing.
enum AiProvider { claude, openai, anthropic, openrouter, nvidia }

/// M21 — Kunci unlock model. Dipakai model selector untuk gate akses:
///   - `open`     : selalu terbuka (default free tier).
///   - `streak7`  : perlu Daily Login Premium (streak ≥ 7 hari).
///   - `pro`      : perlu entitlement KiKai Pro aktif
///                  (via Creator Mission 1.000 views atau streak).
///   - `nvidia`   : perlu entitlement `nvidia_unlock`
///                  (via Creator Mission 5.000 views).
class ModelUnlock {
  static const String open = 'open';
  static const String streak7 = 'streak7';
  static const String pro = 'pro';
  static const String nvidia = 'nvidia';
}

class AiModel {
  final String id;              // ID unik di catalog (untuk selector & DB)
  final String label;           // Label yang tampil di UI
  final AiProvider provider;
  final String endpointPath;    // path relatif dari baseUrl
  final int maxTokens;
  final bool supportsVision;
  final bool supportsFile;
  final bool supportsTools;
  final String description;

  /// ID model *actual* yang dikirim ke provider. Kalau null → pakai [id].
  final String? apiModelId;

  /// M21 — Kunci unlock. Lihat [ModelUnlock]. Default `open`.
  final String unlockKey;

  /// Label yang tampil di badge kunci (mis. "Daily Streak 7 Hari",
  /// "KiKai Pro", "Nvidia Premium"). Kosong = auto dari [unlockKey].
  final String lockedReason;

  /// M23.1 — Path aset ikon (mis. `assets/models/deepseek-v4-pro.png`).
  /// Kalau null / kosong → model selector fallback ke gradient
  /// hexagon default. Ikon dirender bulat 38×38 di tile selector.
  final String? iconAsset;

  /// M33.3 — Persona system prompt tambahan (mode: Santai/Coding/dll).
  /// Digabung ke system prompt dataset sebelum dikirim ke provider.
  final String personaSystemPrompt;

  const AiModel({
    required this.id,
    required this.label,
    required this.provider,
    required this.endpointPath,
    this.maxTokens = 4096,
    this.supportsVision = false,
    this.supportsFile = false,
    this.supportsTools = false,
    this.description = '',
    this.apiModelId,
    this.unlockKey = ModelUnlock.open,
    this.lockedReason = '',
    this.iconAsset,
    this.personaSystemPrompt = '',
  });

  /// ID untuk dikirim ke provider (fallback ke [id]).
  String get effectiveApiId => apiModelId ?? id;

  /// Default = false (open). Runtime UI hitung ulang via
  /// `isModelUnlocked(...)` di model_selector.
  bool get isOpen => unlockKey == ModelUnlock.open;
}
