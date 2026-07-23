class ChatThread {
  final String id;
  final String title;
  final String modelId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool pinned;

  const ChatThread({
    required this.id,
    required this.title,
    required this.modelId,
    required this.createdAt,
    required this.updatedAt,
    this.pinned = false,
  });

  ChatThread copyWith({
    String? title,
    String? modelId,
    DateTime? updatedAt,
    bool? pinned,
  }) =>
      ChatThread(
        id: id,
        title: title ?? this.title,
        modelId: modelId ?? this.modelId,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        pinned: pinned ?? this.pinned,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'modelId': modelId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'pinned': pinned ? 1 : 0,
      };

  factory ChatThread.fromMap(Map<String, dynamic> m) => ChatThread(
        id: m['id'] as String,
        title: m['title'] as String? ?? 'Percakapan baru',
        modelId: m['modelId'] as String? ?? '',
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(m['updatedAt'] as String? ?? '') ??
            DateTime.now(),
        pinned: ((m['pinned'] as num?)?.toInt() ?? 0) == 1,
      );
}
