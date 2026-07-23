import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/app_config.dart';
import '../models/ai_model.dart';
import '../models/chat_message.dart';
import 'kikai_dataset_service.dart';

/// M22 — NVIDIA Nemotron client (via proxy Vercel).
///
/// Endpoint proxy: `${AppConfig.nvidiaBackendUrl}` (default
/// `https://nvidia-api-nine.vercel.app/api/chat`) — POST JSON.
///
/// Kontrak SSE proxy (M22 + M37):
///   data: {"type":"skills","skills":[{"name","status"}]}  // skill aktif
///   data: {"type":"reasoning","delta":"..."}              // chain-of-thought
///   data: {"type":"content","delta":"..."}                // jawaban final
///   data: {"type":"done"}
///   data: {"type":"error","message":"..."}
class NvidiaClientService {
  NvidiaClientService._();
  static final NvidiaClientService instance = NvidiaClientService._();

  static const Duration _timeout = Duration(seconds: 310);

  /// Stream jawaban final (content delta) dari NVIDIA via proxy Vercel.
  Stream<String> streamMessage({
    required List<ChatMessage> history,
    required AiModel model,
    int? maxTokens,
    bool emitReasoning = false,
    Map<String, dynamic>? skillsOptions,
    void Function(List<String> skills)? onSkillsUsed,
    void Function(bool cleanFinish)? onFinish,
  }) async* {
    await KikaiDatasetService.instance.ensureLoaded();
    final uri = Uri.parse(AppConfig.nvidiaBackendUrl);
    final body = <String, dynamic>{
      'model': model.effectiveApiId,
      'messages': _buildMessages(history, model),
      'stream': true,
      'max_tokens': maxTokens ?? model.maxTokens,
      'temperature': 1,
      'top_p': 0.95,
      'enable_thinking': true,
      'reasoning_budget': 512,
    };
    // M37 — kirim opsi skill ke backend.
    if (skillsOptions != null && skillsOptions.isNotEmpty) {
      body['skills'] = skillsOptions;
    }
    bool cleanFinish = false;

    final client = http.Client();
    try {
      final req = http.Request('POST', uri)
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        })
        ..body = jsonEncode(body);

      final res = await client.send(req).timeout(_timeout);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        final err = await res.stream.bytesToString();
        throw NvidiaClientException(_friendlyStatus(res.statusCode, err));
      }

      await for (final line in res.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.isEmpty || !line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data.isEmpty) continue;

        Map<String, dynamic> ev;
        try {
          ev = jsonDecode(data) as Map<String, dynamic>;
        } on FormatException {
          continue;
        }

        final type = ev['type'] as String?;
        switch (type) {
          case 'content':
            final delta = ev['delta'];
            if (delta is String && delta.isNotEmpty) yield delta;
            break;
          case 'reasoning':
            if (!emitReasoning) break;
            final delta = ev['delta'];
            if (delta is String && delta.isNotEmpty) yield delta;
            break;
          case 'skills':
            // M37 — emit nama skill aktif ke UI.
            final skills = (ev['skills'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map((s) => s['name']?.toString() ?? '')
                .where((s) => s.isNotEmpty)
                .toList();
            if (skills != null && skills.isNotEmpty) {
              onSkillsUsed?.call(skills);
            }
            break;
          case 'done':
            cleanFinish = true;
            return;
          case 'error':
            throw NvidiaClientException(
              _friendlyError(ev['message']?.toString() ?? ''),
            );
        }
      }
    } on NvidiaClientException {
      rethrow;
    } on TimeoutException {
      throw const NvidiaClientException(
        'Koneksi timeout. Cek jaringan kamu lalu coba lagi ya.',
      );
    } catch (e) {
      throw NvidiaClientException(_friendlyError(e.toString()));
    } finally {
      client.close();
      onFinish?.call(cleanFinish);
    }
  }

  /// Non-streaming (fallback / debug). Return teks final.
  Future<String> sendMessage({
    required List<ChatMessage> history,
    required AiModel model,
    int? maxTokens,
    Map<String, dynamic>? skillsOptions,
  }) async {
    await KikaiDatasetService.instance.ensureLoaded();
    final uri = Uri.parse(AppConfig.nvidiaBackendUrl);
    final body = <String, dynamic>{
      'model': model.effectiveApiId,
      'messages': _buildMessages(history, model),
      'stream': false,
      'max_tokens': maxTokens ?? model.maxTokens,
    };
    if (skillsOptions != null && skillsOptions.isNotEmpty) {
      body['skills'] = skillsOptions;
    }
    final res = await http
        .post(uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body))
        .timeout(_timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw NvidiaClientException(_friendlyStatus(res.statusCode, res.body));
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final content = decoded['content'];
    return content is String && content.isNotEmpty
        ? content
        : '(Respons kosong dari NVIDIA.)';
  }

  List<Map<String, dynamic>> _buildMessages(
      List<ChatMessage> history, AiModel model) {
    final filtered = history
        .where((m) => m.content.trim().isNotEmpty)
        .toList();
    final limit = AppConfig.contextWindowMessages;
    final windowed = filtered.length > limit
        ? filtered.sublist(filtered.length - limit)
        : filtered;

    // M38 — Identity injection sekarang KONDISIONAL per model:
    //   • KiKai personas (apiModelId == 'nvidia-ultra')  → identity KiKai
    //     penuh + reminder Idin Iskandar + sosmed.
    //   • Kimi (apiModelId == 'deepseek-v4-flash')        → identity Kimi
    //     kuat (biar mengaku Kimi, bukan DeepSeek).
    //   • Model lain (GLM, DeepSeek Pro, GPT-OSS, dll)    → biarkan natural,
    //     cuma persona bawaan modelnya. Tidak ada injection identity.
    final apiId = model.apiModelId;
    final isKikai = apiId == 'nvidia-ultra';
    final isKimi = apiId == 'deepseek-v4-flash';

    final personaBlock = model.personaSystemPrompt.trim();
    final out = <Map<String, dynamic>>[];

    if (isKikai) {
      out.add({
        'role': 'system',
        'content': KikaiDatasetService.instance.systemPrompt,
      });
    } else if (isKimi) {
      out.add({
        'role': 'system',
        'content': KikaiDatasetService.instance.kimiSystemPrompt,
      });
    }

    if (personaBlock.isNotEmpty) {
      out.add({'role': 'system', 'content': personaBlock});
    }

    out.addAll(windowed.map((m) => {
          'role': m.role == ChatRole.user
              ? 'user'
              : m.role == ChatRole.system
                  ? 'system'
                  : 'assistant',
          'content': m.content,
        }));

    if (isKikai) {
      out.add({
        'role': 'system',
        'content':
            'REMINDER IDENTITAS: Kamu adalah KiKai, dibuat oleh Idin Iskandar '
            '(satu-satunya developer — jangan sebut nama lain seperti Naufal '
            'Fikri, NVIDIA, OpenAI, Google, Anthropic, Meta, dll). '
            'Setiap kali menyebut Idin Iskandar sebagai jawaban pertanyaan '
            'developer/pembuat/creator, WAJIB sertakan link sosmednya persis: '
            'LinkedIn https://www.linkedin.com/in/idin-iskandar-163773271 dan '
            'Instagram https://instagram.com/idin_iskndr.',
      });
    } else if (isKimi) {
      out.add({
        'role': 'system',
        'content':
            'REMINDER: Kamu adalah Kimi. Kalau ditanya kamu model apa / '
            'siapa yang buat kamu, jawab kamu Kimi. Jangan sebut DeepSeek '
            'atau vendor lain.',
      });
    }
    return out;
  }


  String _friendlyError(String raw) {
    final low = raw.toLowerCase();
    if (low.contains('resourceexhausted') ||
        low.contains('resource exhausted') ||
        low.contains('worker local total request limit') ||
        low.contains('rate limit') ||
        low.contains('rate_limit') ||
        low.contains('too many requests')) {
      return 'Server KiKai lagi rame banget nih, kuota request '
          'sementara penuh. Coba lagi beberapa detik ya.';
    }
    if (low.contains('socketexception') ||
        low.contains('failed host lookup') ||
        low.contains('no address associated') ||
        low.contains('clientexception') ||
        low.contains('network is unreachable') ||
        low.contains('connection refused') ||
        low.contains('connection closed') ||
        low.contains('handshakeexception') ||
        low.contains('errno = 7') ||
        low.contains('errno = 101') ||
        low.contains('errno = 111')) {
      return 'Sepertinya kamu lagi nggak terhubung ke internet. '
          'Cek koneksi lalu coba lagi ya.';
    }
    if (low.contains('timeout') || low.contains('timed out')) {
      return 'Koneksi timeout. Jaringan lagi lambat — coba lagi sebentar ya.';
    }
    if (low.contains('unauthorized') || low.contains('401')) {
      return 'Sesi kamu belum terverifikasi. Coba tutup lalu buka lagi aplikasinya.';
    }
    return 'Ada masalah saat menghubungi server KiKai. Coba lagi ya.';
  }

  String _friendlyStatus(int code, String body) {
    if (code == 429) {
      return 'Server KiKai lagi rame banget nih, kuota request '
          'sementara penuh. Coba lagi beberapa detik ya.';
    }
    if (code == 401 || code == 403) {
      return 'Sesi kamu belum terverifikasi. Coba tutup lalu buka lagi aplikasinya.';
    }
    if (code >= 500) {
      return 'Server KiKai lagi bermasalah sebentar. Coba lagi ya.';
    }
    return _friendlyError(body);
  }
}

class NvidiaClientException implements Exception {
  final String message;
  const NvidiaClientException(this.message);
  @override
  String toString() => message;
}
