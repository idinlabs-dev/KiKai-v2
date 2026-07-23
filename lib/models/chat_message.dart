import 'dart:convert';

import 'attachment.dart';

enum ChatRole { user, assistant, system }

/// M39 — Sumber (citation) yang ditempel ke pesan assistant.
/// Dipersist bareng pesan supaya "Sumber" tetap muncul saat thread di-reload.
class MessageSource {
  final int index;
  final String title;
  final String url;
  const MessageSource({
    required this.index,
    required this.title,
    required this.url,
  });

  Map<String, dynamic> toMap() => {
        'index': index,
        'title': title,
        'url': url,
      };

  factory MessageSource.fromMap(Map<String, dynamic> m) => MessageSource(
        index: (m['index'] as num?)?.toInt() ?? 0,
        title: (m['title'] as String?) ?? '',
        url: (m['url'] as String?) ?? '',
      );
}

class ChatMessage {
  final String id;
  final String threadId;
  final ChatRole role;

  /// Isi pesan yang **ditampilkan ke user** di UI.
  /// - Untuk pesan user: teks asli user (bersih, tanpa prompt engineering).
  /// - Untuk pesan assistant: hasil respons LLM.
  final String content;

  /// M39 — Konteks tambahan yang **hanya dikirim ke LLM**, TIDAK di-render
  /// ke UI. Dipakai untuk inject hasil web search / read-url sebagai konteks
  /// tersembunyi supaya bubble user tetap bersih (mirip ChatGPT).
  final String? hiddenPromptContext;

  /// M39 — Daftar sumber (citation) yang di-render sebagai kartu di bawah
  /// pesan assistant. Untuk pesan user biasanya kosong.
  final List<MessageSource> sources;

  /// M40 — Follow-up suggestion chips (mirip ChatGPT). Digenerate setelah
  /// stream assistant selesai. Tap chip → kirim sebagai pesan baru.
  final List<String> followUps;

  final List<Attachment> attachments;
  final DateTime createdAt;
  final bool isStreaming;

  /// M41 — Menandai pesan assistant sebagai hasil DeepResearch.
  /// Dipersist supaya kartu "Buka" tetap muncul saat thread
  /// di-reload dari history, meski skill aktif sudah bukan aiq_research.
  final bool isResearchReport;

  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.role,
    required this.content,
    this.hiddenPromptContext,
    this.sources = const [],
    this.followUps = const [],
    this.attachments = const [],
    required this.createdAt,
    this.isStreaming = false,
    this.isResearchReport = false,
  });

  /// Isi efektif yang dikirim ke LLM (bukan yang ditampilkan di UI).
  /// Kalau ada hiddenPromptContext → prepend sebelum content.
  String get effectiveLlmContent {
    final ctx = hiddenPromptContext;
    if (ctx == null || ctx.isEmpty) return content;
    return '$ctx\n\nPertanyaan user:\n$content';
  }

  ChatMessage copyWith({
    String? content,
    bool? isStreaming,
    List<Attachment>? attachments,
    String? hiddenPromptContext,
    List<MessageSource>? sources,
    List<String>? followUps,
    bool? isResearchReport,
    bool clearHiddenPromptContext = false,
  }) =>
      ChatMessage(
        id: id,
        threadId: threadId,
        role: role,
        content: content ?? this.content,
        hiddenPromptContext: clearHiddenPromptContext
            ? null
            : (hiddenPromptContext ?? this.hiddenPromptContext),
        sources: sources ?? this.sources,
        followUps: followUps ?? this.followUps,
        attachments: attachments ?? this.attachments,
        createdAt: createdAt,
        isStreaming: isStreaming ?? this.isStreaming,
        isResearchReport: isResearchReport ?? this.isResearchReport,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'threadId': threadId,
        'role': role.name,
        'content': content,
        'hiddenPromptContext': hiddenPromptContext,
        'sources': jsonEncode(sources.map((s) => s.toMap()).toList()),
        'followUps': jsonEncode(followUps),
        'attachments': attachments.map((a) => a.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'isResearchReport': isResearchReport ? 1 : 0,
      };

  factory ChatMessage.fromMap(Map<String, dynamic> m) {
    // sources bisa datang sebagai List<Map> (in-memory) atau String JSON (dari DB).
    List<MessageSource> parsedSources = const [];
    final rawSources = m['sources'];
    if (rawSources is String && rawSources.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawSources);
        if (decoded is List) {
          parsedSources = decoded
              .whereType<Map>()
              .map((e) => MessageSource.fromMap(Map<String, dynamic>.from(e)))
              .toList();
        }
      } catch (_) {}
    } else if (rawSources is List) {
      parsedSources = rawSources
          .whereType<Map>()
          .map((e) => MessageSource.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }

    // followUps (M40)
    List<String> parsedFollowUps = const [];
    final rawFu = m['followUps'];
    if (rawFu is String && rawFu.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawFu);
        if (decoded is List) {
          parsedFollowUps =
              decoded.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
      } catch (_) {}
    } else if (rawFu is List) {
      parsedFollowUps =
          rawFu.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    final rawIsResearch = m['isResearchReport'];
    final bool isResearchReport = rawIsResearch is bool
        ? rawIsResearch
        : rawIsResearch is num
            ? rawIsResearch.toInt() != 0
            : (rawIsResearch is String && (rawIsResearch == '1' || rawIsResearch.toLowerCase() == 'true'));

    return ChatMessage(
      id: m['id'] as String,
      threadId: m['threadId'] as String? ?? '',
      role: ChatRole.values.firstWhere(
        (e) => e.name == (m['role'] as String? ?? 'user'),
        orElse: () => ChatRole.user,
      ),
      content: m['content'] as String? ?? '',
      hiddenPromptContext: m['hiddenPromptContext'] as String?,
      sources: parsedSources,
      followUps: parsedFollowUps,
      attachments: (m['attachments'] as List<dynamic>? ?? [])
          .map((e) => Attachment.fromMap(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isResearchReport: isResearchReport,
    );
  }
}
