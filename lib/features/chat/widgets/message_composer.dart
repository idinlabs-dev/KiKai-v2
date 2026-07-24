import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';

/// KiKai — Composer (monokrom).
///
/// M32 update:
///  - Ikon lampiran sekarang membuka **file picker universal** (kode/PDF/
///    DOCX/txt/dll). File dibaca → dinormalisasi ke blok Markdown yang
///    disisipkan ke prompt sebelum text user.
///  - Ikon kamera membuka file picker gambar. Karena backend teks-only,
///    gambar dilampirkan sebagai metadata (nama + ukuran + base64 preview
///    kecil) supaya model tetap punya konteks tanpa merusak alur teks.
class MessageComposer extends StatefulWidget {
  final bool isSending;
  final ValueChanged<String> onSend;
  final VoidCallback onStop;

  /// M38 — Web search toggle. Kalau `onToggleWebSearch` null, tombol
  /// tidak muncul (backward compatible).
  final bool webSearchEnabled;
  final VoidCallback? onToggleWebSearch;

  /// Banner status (mis. "KiKai lagi googling..."). Null = disembunyikan.
  final String? statusMessage;

  const MessageComposer({
    super.key,
    required this.isSending,
    required this.onSend,
    required this.onStop,
    this.webSearchEnabled = false,
    this.onToggleWebSearch,
    this.statusMessage,
  });

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _hasText = false;

  final List<_Attachment> _attachments = [];
  bool _picking = false;

  static const int _maxInlineBytes = 200 * 1024; // 200 KB text inline

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final has = _ctrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _canSend =>
      (_hasText || _attachments.isNotEmpty) && !widget.isSending;

  void _submit() {
    if (!_canSend) return;
    final userText = _ctrl.text.trim();
    final buf = StringBuffer();
    for (final a in _attachments) {
      buf.writeln(a.toPromptBlock());
      buf.writeln();
    }
    if (userText.isNotEmpty) buf.writeln(userText);
    widget.onSend(buf.toString().trim());
    _ctrl.clear();
    setState(() {
      _hasText = false;
      _attachments.clear();
    });
  }

  Future<void> _pickAny() async {
    await _pick(FileType.any);
  }


  Future<void> _pick(FileType type, {bool imageMode = false}) async {
    if (_picking || widget.isSending) return;
    _picking = true;
    try {
      final res = await FilePicker.platform.pickFiles(
        type: type,
        withData: true,
        allowMultiple: false,
      );
      if (res == null || res.files.isEmpty) return;
      final f = res.files.first;
      final Uint8List? bytes = f.bytes;
      if (bytes == null) {
        _toast('Gagal membaca file.');
        return;
      }
      final att = _buildAttachment(
        name: f.name,
        bytes: bytes,
        isImage: imageMode,
      );
      setState(() => _attachments.add(att));
    } catch (e) {
      _toast('Gagal memilih file: $e');
    } finally {
      _picking = false;
    }
  }

  _Attachment _buildAttachment({
    required String name,
    required Uint8List bytes,
    required bool isImage,
  }) {
    // M43 — auto-detect gambar berdasar ekstensi supaya lampiran image
    // (dari file picker apapun) otomatis ke-route ke vision.
    final looksLikeImage = isImage || _looksLikeImageName(name);
    if (looksLikeImage) {
      // M43 — simpan bytes gambar supaya bisa dikirim ke kie.ai vision proxy.
      return _Attachment.image(
        name: name,
        sizeBytes: bytes.length,
        bytes: bytes,
        mime: _guessImageMime(name),
      );
    }
    // Coba decode utf-8 (kode/py/js/json/md/txt/csv/html/xml/dll).
    if (bytes.length <= _maxInlineBytes) {
      try {
        final text = utf8.decode(bytes, allowMalformed: false);
        return _Attachment.text(
          name: name,
          content: text,
          sizeBytes: bytes.length,
        );
      } catch (_) {/* biner → fallback bawah */}
    }
    // Biner besar (pdf/docx/dll) → lampirkan metadata saja.
    return _Attachment.binary(
      name: name,
      sizeBytes: bytes.length,
    );
  }

  String _guessImageMime(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.gif')) return 'image/gif';
    if (n.endsWith('.bmp')) return 'image/bmp';
    return 'image/jpeg';
  }

  bool _looksLikeImageName(String name) {
    final n = name.toLowerCase();
    return n.endsWith('.png') ||
        n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.webp') ||
        n.endsWith('.gif') ||
        n.endsWith('.bmp');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final showStop = widget.isSending;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (int i = 0; i < _attachments.length; i++)
                      _attachments[i].kind == _AttKind.image
                          ? _ImageThumbPreview(
                              att: _attachments[i],
                              onRemove: () =>
                                  setState(() => _attachments.removeAt(i)),
                            )
                          : _AttachmentChip(
                              att: _attachments[i],
                              onRemove: () =>
                                  setState(() => _attachments.removeAt(i)),
                            ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        _InlineIcon(
                            icon: LucideIcons.paperclip, onTap: _pickAny),
                        if (widget.onToggleWebSearch != null)
                          _WebSearchToggle(
                            enabled: widget.webSearchEnabled,
                            onTap: widget.onToggleWebSearch!,
                          ),
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            focusNode: _focus,
                            minLines: 1,
                            maxLines: 5,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                            ),
                            textInputAction: TextInputAction.newline,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                                  hintText: 'Ask anything...',
                              hintStyle:
                                  TextStyle(color: AppColors.textMuted),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: showStop
                      ? _SendButton(
                          key: const ValueKey('stop'),
                          icon: LucideIcons.stopCircle,
                          onTap: widget.onStop,
                          enabled: true,
                        )
                      : _SendButton(
                          key: const ValueKey('send'),
                          icon: LucideIcons.arrowUp,
                          onTap: _canSend ? _submit : null,
                          enabled: _canSend,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Attachment model ────────────────────────────────────────────────────

enum _AttKind { text, binary, image }

class _Attachment {
  final _AttKind kind;
  final String name;
  final int sizeBytes;
  final String? content; // hanya utk kind == text
  final Uint8List? bytes; // hanya utk kind == image
  final String? mime; // hanya utk kind == image

  const _Attachment._(
      {required this.kind,
      required this.name,
      required this.sizeBytes,
      this.content,
      this.bytes,
      this.mime});

  factory _Attachment.text(
          {required String name,
          required String content,
          required int sizeBytes}) =>
      _Attachment._(
          kind: _AttKind.text,
          name: name,
          sizeBytes: sizeBytes,
          content: content);

  factory _Attachment.binary(
          {required String name, required int sizeBytes}) =>
      _Attachment._(kind: _AttKind.binary, name: name, sizeBytes: sizeBytes);

  factory _Attachment.image({
    required String name,
    required int sizeBytes,
    required Uint8List bytes,
    required String mime,
  }) =>
      _Attachment._(
          kind: _AttKind.image,
          name: name,
          sizeBytes: sizeBytes,
          bytes: bytes,
          mime: mime);

  String get sizeLabel {
    if (sizeBytes < 1024) return '${sizeBytes}B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)}MB';
  }

  String toPromptBlock() {
    // Sentinel diparse oleh message_bubble supaya user cuma lihat chip.
    // Untuk image, blob base64 disisipkan lewat sentinel terpisah
    // <<<KIKAI_IMAGE_BLOB ...>>> yang di-strip oleh ChatController
    // sebelum konten user disimpan / dirender.
    switch (kind) {
      case _AttKind.text:
        final ext = name.contains('.') ? name.split('.').last : '';
        return '<<<KIKAI_FILE name="$name" size="$sizeLabel" kind="text">>>\n'
            '```$ext\n${content ?? ''}\n```\n'
            '<<<KIKAI_FILE_END>>>';
      case _AttKind.binary:
        return '<<<KIKAI_FILE name="$name" size="$sizeLabel" kind="binary">>>\n'
            '(Isi file biner tidak dilampirkan — jawab berdasarkan '
            'konteks nama file & permintaan user.)\n'
            '<<<KIKAI_FILE_END>>>';
      case _AttKind.image:
        final b64 = bytes == null ? '' : base64Encode(bytes!);
        final m = mime ?? 'image/jpeg';
        // M44 — sentinel tunggal untuk gambar. Berisi mime + base64 supaya
        // ChatController bisa extract → kirim ke kie.ai vision, DAN
        // message_bubble bisa render preview thumbnail (mirip ChatGPT).
        return '<<<KIKAI_IMAGE mime="$m" name="$name" size="$sizeLabel" data="$b64">>>';
    }
  }

  IconData get icon {
    switch (kind) {
      case _AttKind.image:
        return LucideIcons.image;
      case _AttKind.text:
        return LucideIcons.fileText;
      case _AttKind.binary:
        return LucideIcons.file;
    }
  }
}

class _AttachmentChip extends StatelessWidget {
  final _Attachment att;
  final VoidCallback onRemove;
  const _AttachmentChip({required this.att, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(att.icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(
            att.name,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 6),
        Text(att.sizeLabel,
            style:
                const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        InkWell(
          onTap: onRemove,
          borderRadius: BorderRadius.circular(999),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(LucideIcons.x,
                size: 14, color: AppColors.textMuted),
          ),
        ),
      ]),
    );
  }
}

class _InlineIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _InlineIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: AppColors.textSecondary, size: 24),
      splashRadius: 20,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      padding: EdgeInsets.zero,
    );
  }
}

class _SendButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  const _SendButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.surface, size: 28),
          ),
        ),
      ),
    );
  }
}

/// M38 — Tombol toggle "web search" (globe icon).
class _WebSearchToggle extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _WebSearchToggle({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.primary : AppColors.textSecondary;
    return Tooltip(
      message: enabled ? 'Web search: ON' : 'Web search: OFF',
      child: IconButton(
        onPressed: onTap,
        icon: Icon(
          enabled ? LucideIcons.search : LucideIcons.globe2,
          color: color,
          size: 22,
        ),
        splashRadius: 20,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

/// M44 — Thumbnail preview untuk gambar di composer (ChatGPT-style):
/// kotak persegi ~64px dengan tombol X di pojok kanan atas.
class _ImageThumbPreview extends StatelessWidget {
  final _Attachment att;
  final VoidCallback onRemove;
  const _ImageThumbPreview({required this.att, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final bytes = att.bytes;
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: AppColors.surfaceElevated,
                child: bytes != null
                    ? Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
                    : const Icon(Icons.image_outlined,
                        color: AppColors.textMuted),
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: const Icon(LucideIcons.x,
                    size: 14, color: AppColors.surface),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
