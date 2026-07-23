import '../../models/ai_model.dart';

/// Katalog model AI KiKai.
///
/// Model "KiKai" adalah satu model tunggal (backend `nvidia-ultra`) dengan
/// persona universal — menggantikan 4 mode terpisah (Santai / Coding /
/// Hacking / Universal) yang sebelumnya semuanya juga di-back oleh model
/// dasar yang sama.
const List<AiModel> kAiModels = [
  AiModel(
    id: 'kikai',
    apiModelId: 'nvidia-ultra',
    label: 'KiKai',
    provider: AiProvider.nvidia,
    endpointPath: '/api/chat',
    maxTokens: 32768,
    supportsFile: true,
    supportsTools: true,
    description:
        'Asisten AI serba-bisa dari KiKai — cocok untuk ngobrol santai, '
        'coding, riset, security, dan tugas harian lainnya. Adaptif '
        'mengikuti gaya pertanyaan kamu.',
    unlockKey: ModelUnlock.open,
    iconAsset: 'assets/models/kikai.png',
    personaSystemPrompt:
        'Kamu adalah KiKai, asisten AI serba-bisa. Adaptasi gaya jawab '
        'ke konteks pertanyaan: teknis kalau ditanya teknis, hangat '
        'kalau diajak ngobrol, tegas & detail kalau ditanya security. '
        'Bahasa Indonesia natural, jelas, dan terstruktur.',
  ),

  // ── Model eksternal (via NVIDIA proxy, alias registry) ─────────────
  AiModel(
    id: 'glm-5.2',
    apiModelId: 'glm-5.2',
    label: 'GLM 5.2',
    provider: AiProvider.nvidia,
    endpointPath: '/api/chat',
    maxTokens: 32768,
    supportsFile: true,
    supportsTools: true,
    description:
        'Z.ai GLM 5.2 — model bahasa canggih dari Zhipu AI. Kuat di '
        'reasoning multi-bahasa, penulisan panjang, dan pemahaman '
        'konteks kompleks. Cocok buat riset, analisis dokumen, dan '
        'penulisan kreatif.',
    unlockKey: ModelUnlock.open,
    iconAsset: 'assets/models/z.png',
    personaSystemPrompt:
        'Kamu adalah GLM 5.2, asisten AI serbaguna. Jawab dengan jelas, '
        'terstruktur, dan berbahasa Indonesia natural.',
  ),
  // Slot ex-"DeepSeek V4 Flash" — di-rebrand jadi Kimi (label + ikon),
  // tapi apiModelId tetap `deepseek-v4-flash` karena endpoint Kimi asli
  // di proxy NVIDIA sudah tidak tersedia. User dapat pengalaman "Kimi"
  // tanpa error backend.
  AiModel(
    id: 'kimi',
    apiModelId: 'deepseek-v4-flash',
    label: 'Kimi',
    provider: AiProvider.nvidia,
    endpointPath: '/api/chat',
    maxTokens: 16384,
    supportsFile: true,
    supportsTools: true,
    description:
        'Kimi — asisten cepat dengan long-context style. Latency rendah, '
        'jawaban ngebut, cocok buat tanya-jawab harian, ringkasan, dan '
        'Q&A cepat.',
    unlockKey: ModelUnlock.open,
    iconAsset: 'assets/models/kimi.png',
    personaSystemPrompt:
        'Kamu adalah Kimi, asisten AI cepat & natural. Jawab ringkas, '
        'akurat, dan berbahasa Indonesia natural.',
  ),
  AiModel(
    id: 'gpt-oss-20b',
    apiModelId: 'gpt-oss-20b',
    label: 'GPT-OSS 20B',
    provider: AiProvider.nvidia,
    endpointPath: '/api/chat',
    maxTokens: 16384,
    supportsFile: true,
    supportsTools: true,
    description:
        'OpenAI GPT-OSS 20B — model open-source dari OpenAI. Balanced '
        'antara kualitas dan kecepatan, kuat di instruction-following '
        'dan general knowledge.',
    unlockKey: ModelUnlock.open,
    iconAsset: 'assets/models/openai.png',
    personaSystemPrompt:
        'Kamu adalah GPT-OSS 20B, asisten AI open-source. Jawab '
        'informatif dan terstruktur. Bahasa Indonesia natural.',
  ),
];

/// Model KiKai (persona internal, backend nvidia-ultra) — kini tunggal.
List<AiModel> get kKikaiPersonas =>
    kAiModels.where((m) => m.apiModelId == 'nvidia-ultra').toList();

/// Model AI eksternal (alias di proxy NVIDIA).
List<AiModel> get kExternalModels =>
    kAiModels.where((m) => m.apiModelId != 'nvidia-ultra').toList();

/// Cari model by id (catalog id, bukan apiModelId).
AiModel? findModelById(String id) {
  for (final m in kAiModels) {
    if (m.id == id) return m;
  }
  for (final m in kAiModels) {
    if (m.apiModelId == id) return m;
  }
  return null;
}

/// Model default untuk user baru.
AiModel get kDefaultFreeModel => kAiModels.firstWhere(
      (m) => m.id == 'kikai',
      orElse: () => kAiModels.first,
    );
