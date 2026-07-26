import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/constants/app_config.dart';
import '../models/chat_message.dart';

/// M43 — KiKai Vision client. Streaming multimodal (teks + gambar) melalui
/// backend Vercel `/api/vision`, yang meneruskan ke kie.ai GPT-5-2.
///
/// Kontrak SSE identik dengan `NvidiaClientService`:
///   data: {"type":"content","delta":"..."}
///   data: {"type":"done"}
///   data: {"type":"error","message":"..."}
class VisionImage {
  final String mime;
  final Uint8List bytes;
  const VisionImage({required this.mime, required this.bytes});

  Map<String, String> toJson() => {
        'mime': mime,
        'data': base64Encode(bytes),
      };
}

class VisionClientService {
  VisionClientService._();
  static final VisionClientService instance = VisionClientService._();

  static const Duration _timeout = Duration(seconds: 310);

  Stream<String> streamMessage({
    required String prompt,
    required List<VisionImage> images,
    List<ChatMessage> history = const [],
    bool useSearch = false,
    String? systemPrompt,
    void Function(bool cleanFinish)? onFinish,
  }) async* {
    final uri = Uri.parse('${AppConfig.webBackendBase}/vision');
    final hist = history
        .where((m) =>
            m.role != ChatRole.system && m.content.trim().isNotEmpty)
        .toList();
    final limit = AppConfig.contextWindowMessages;
    final windowed =
        hist.length > limit ? hist.sublist(hist.length - limit) : hist;

    final body = jsonEncode({
      'prompt': prompt,
      'images': images.map((i) => i.toJson()).toList(),
      'useSearch': useSearch,
      if (systemPrompt != null && systemPrompt.trim().isNotEmpty)
        'systemPrompt': systemPrompt,
      'history': windowed
          .map((m) => {
                'role': m.role == ChatRole.user ? 'user' : 'assistant',
                'content': m.content,
              })
          .toList(),
    });

    bool cleanFinish = false;
    final client = http.Client();
    try {
      final req = http.Request('POST', uri)
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        })
        ..body = body;

      final res = await client.send(req).timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        final err = await res.stream.bytesToString();
        throw VisionClientException(
            'Vision HTTP ${res.statusCode}: ${err.substring(0, err.length > 200 ? 200 : err.length)}');
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
          case 'done':
            cleanFinish = true;
            return;
          case 'error':
            throw VisionClientException(
                ev['message']?.toString() ?? 'unknown vision error');
        }
      }
    } on VisionClientException {
      rethrow;
    } on TimeoutException {
      throw const VisionClientException(
          'Timeout saat baca gambar. Coba lagi.');
    } catch (e) {
      throw VisionClientException('Vision gagal: $e');
    } finally {
      onFinish?.call(cleanFinish);
      client.close();
    }
  }
}

class VisionClientException implements Exception {
  final String message;
  const VisionClientException(this.message);
  @override
  String toString() => message;
}
