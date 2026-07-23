import 'dart:async';

import '../core/constants/ai_models.dart';
import '../core/constants/app_config.dart';
import '../models/ai_model.dart';
import '../models/chat_message.dart';
import 'nvidia_client_service.dart';
import 'skills_service.dart';

/// AI client — semua request diteruskan ke proxy Vercel
/// ([NvidiaClientService]). Tidak ada API key lokal / GitHub-injected key
/// lagi; auth ditangani sepenuhnya di sisi backend.
class AiClientService {
  AiClientService._();
  static final AiClientService instance = AiClientService._();

  /// Kirim satu round chat non-streaming. Return teks respons assistant.
  Future<String> sendMessage({
    required List<ChatMessage> history,
    AiModel? model,
    int? maxTokens,
  }) async {
    final selected = _resolveModel(model);
    try {
      return await NvidiaClientService.instance.sendMessage(
        history: history,
        model: selected,
        maxTokens: maxTokens,
        skillsOptions: _skillsOptions(),
      );
    } on NvidiaClientException catch (e) {
      throw AiClientException(e.message);
    }
  }

  /// Stream teks respons assistant. Emit delta text setiap event.
  Stream<String> streamMessage({
    required List<ChatMessage> history,
    AiModel? model,
    int? maxTokens,
    void Function(bool cleanFinish)? onFinish,
  }) async* {
    final selected = _resolveModel(model);
    try {
      yield* NvidiaClientService.instance.streamMessage(
        history: history,
        model: selected,
        maxTokens: maxTokens,
        skillsOptions: _skillsOptions(),
        onFinish: onFinish,
      );
    } on NvidiaClientException catch (e) {
      throw AiClientException(e.message);
    }
  }

  Map<String, dynamic> _skillsOptions() {
    SkillsService.instance.load();
    return SkillsService.instance.buildOptions();
  }

  AiModel _resolveModel(AiModel? model) =>
      model ?? findModelById(AppConfig.defaultModelId) ?? kDefaultFreeModel;
}

class AiClientException implements Exception {
  final String message;
  const AiClientException(this.message);
  @override
  String toString() => message;
}
