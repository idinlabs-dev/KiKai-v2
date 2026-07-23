/// Attachment model — dipakai composer & AI request builder (M4).
enum AttachmentType { image, file, code }

class Attachment {
  final AttachmentType type;
  final String path;            // path lokal / URL / base64 marker
  final String filename;
  final String mime;
  final int sizeBytes;
  final String? language;       // untuk code file
  final String? base64;         // untuk image kalau perlu inline

  const Attachment({
    required this.type,
    required this.path,
    required this.filename,
    required this.mime,
    required this.sizeBytes,
    this.language,
    this.base64,
  });

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'path': path,
        'filename': filename,
        'mime': mime,
        'sizeBytes': sizeBytes,
        'language': language,
      };

  factory Attachment.fromMap(Map<String, dynamic> m) => Attachment(
        type: AttachmentType.values.firstWhere(
          (e) => e.name == (m['type'] as String? ?? 'file'),
          orElse: () => AttachmentType.file,
        ),
        path: m['path'] as String? ?? '',
        filename: m['filename'] as String? ?? '',
        mime: m['mime'] as String? ?? 'application/octet-stream',
        sizeBytes: (m['sizeBytes'] as num?)?.toInt() ?? 0,
        language: m['language'] as String?,
      );
}
