import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../core/theme/app_colors.dart';
import '../../../models/chat_message.dart';
import '../../../services/skills_service.dart';
import 'code_block.dart';
import 'deep_research_card.dart';
import 'thinking_indicator.dart';

/// KiKai — Message bubble (monokrom).
///
/// - **User**: rata kanan, bubble hitam pekat + teks putih, timestamp
///   di bawah bubble.
/// - **Assistant**: avatar "K" bulat hitam + nama "Kikai", teks polos
///   (tanpa kartu), markdown + code block terang.
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  /// Topik (biasanya isi pesan user tepat sebelum balasan asisten). Dipakai
  /// oleh header kartu DeepResearch — "Riset {topic}".
  final String? researchTopic;

  /// M40 — callback saat user tap salah satu chip follow-up. Diisi dari
  /// chat_screen supaya bisa langsung memanggil `controller.sendUserMessage`.
  final ValueChanged<String>? onFollowUpTap;

  const MessageBubble({
    super.key,
    required this.message,
    this.researchTopic,
    this.onFollowUpTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    if (isUser) return _UserRow(message: message);
    return _AssistantRow(
      message: message,
      researchTopic: researchTopic,
      onFollowUpTap: onFollowUpTap,
    );
  }
}

/// Avatar "K" hitam-putih untuk asisten.
class KAvatar extends StatelessWidget {
  final double size;
  const KAvatar({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        'K',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.5,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

String _formatTime(DateTime d) => DateFormat('HH:mm').format(d.toLocal());

class _UserRow extends StatelessWidget {
  final ChatMessage message;
  const _UserRow({required this.message});

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width * 0.8;
    final parsed = _parseUserContent(message.content);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (parsed.images.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final img in parsed.images)
                      _UserImageView(img: img),
                  ],
                ),
              ),
            ),
          if (parsed.attachments.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in parsed.attachments) _FileChipView(att: a),
                  ],
                ),
              ),
            ),
          if (parsed.text.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: GestureDetector(
                onLongPress: () => _copy(context, message.content),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: AppColors.bubbleUser,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                  child: Text(
                    parsed.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              _formatTime(message.createdAt),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantRow extends StatelessWidget {
  final ChatMessage message;
  final String? researchTopic;
  final ValueChanged<String>? onFollowUpTap;
  const _AssistantRow({
    required this.message,
    this.researchTopic,
    this.onFollowUpTap,
  });

  @override
  Widget build(BuildContext context) {
    final isStreamingEmpty = message.isStreaming && message.content.isEmpty;
    // M43 — Kartu riset HANYA dimunculkan bila message ini memang tercatat
    // sebagai laporan riset (`isResearchReport`, di-set saat kirim dgn
    // skill aiq_research aktif) atau bila stream aktif dengan skill
    // riset. Jangan bergantung ke `researchTopic` (selalu terisi) atau
    // ke skill aktif untuk pesan lama — kalau tidak, pindah skill ke
    // Default akan salah munculkan kartu riset pada chat non-riset,
    // dan pindah ke DeepResearch akan salah tampilkan kartu di pesan
    // default lama.
    final activeSkillIsResearch = SkillsService.instance.activeSkill ==
        SkillsService.kSkillAiqResearch;
    final isResearch = message.isResearchReport ||
        (message.isStreaming && activeSkillIsResearch);
    final showPlanCard = isResearch && message.isStreaming;
    final showCompletedCard =
        isResearch && !message.isStreaming && message.content.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KAvatar(size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onLongPress: () => _copy(context, message.content),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      'Kikai',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (showPlanCard)
                    DeepResearchCard(
                      topic: researchTopic ?? '',
                      active: message.isStreaming,
                      streamingContent: message.content,
                    ),
                  if (showCompletedCard) ...[
                    const Padding(
                      padding: EdgeInsets.only(top: 2, bottom: 6),
                      child: Text(
                        'Aku sudah menyelesaikan risetmu.',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14.5,
                          height: 1.45,
                        ),
                      ),
                    ),
                    DeepResearchCard(
                      topic: researchTopic ?? '',
                      active: false,
                      reportMarkdown: message.content,
                      completedAt: message.createdAt,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (isStreamingEmpty && !showPlanCard)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: ThinkingIndicator(),
                    )

                  else if (!showCompletedCard && !showPlanCard)
                    MarkdownBody(
                      data: message.content,
                      selectable: true,
                      styleSheet: _markdownStyle(),
                      softLineBreak: true,
                      builders: {'code': _CodeElementBuilder()},
                      extensionSet: md.ExtensionSet(
                        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                        [
                          md.EmojiSyntax(),
                          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                        ],
                      ),
                    ),
                  if (message.isStreaming && !isStreamingEmpty && !showPlanCard) ...[
                    const SizedBox(height: 6),
                    const _BlinkingCursor(),
                  ],
                  // M39 — Kartu Sumber (citations) di bawah jawaban.
                  // M40 — Sekarang collapsible: klik header buka/tutup.
                  if (message.sources.isNotEmpty && !message.isStreaming) ...[
                    const SizedBox(height: 12),
                    _SourcesCard(sources: message.sources),
                  ],
                  // M40 — Follow-up suggestion chips.
                  if (message.followUps.isNotEmpty &&
                      !message.isStreaming &&
                      onFollowUpTap != null) ...[
                    const SizedBox(height: 12),
                    _FollowUpsRow(
                      followUps: message.followUps,
                      onTap: onFollowUpTap!,
                    ),
                  ],
                  if (!isStreamingEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(message.createdAt),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  MarkdownStyleSheet _markdownStyle() {
    const baseColor = AppColors.textPrimary;
    return MarkdownStyleSheet(
      p: const TextStyle(color: baseColor, fontSize: 15, height: 1.55),
      h1: const TextStyle(
          color: baseColor, fontSize: 21, fontWeight: FontWeight.w800),
      h2: const TextStyle(
          color: baseColor, fontSize: 18, fontWeight: FontWeight.w800),
      h3: const TextStyle(
          color: baseColor, fontSize: 16, fontWeight: FontWeight.w700),
      strong: const TextStyle(color: baseColor, fontWeight: FontWeight.w800),
      em: const TextStyle(color: baseColor, fontStyle: FontStyle.italic),
      a: const TextStyle(
          color: baseColor,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w600),
      listBullet: const TextStyle(color: baseColor, fontSize: 15),
      blockquote:
          const TextStyle(color: AppColors.textSecondary, fontSize: 15),
      blockquoteDecoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
      code: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        color: AppColors.textPrimary,
        backgroundColor: AppColors.surfaceHigh,
      ),
      codeblockDecoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      tableBorder: TableBorder.all(color: AppColors.divider, width: 1),
      tableHead: const TextStyle(
          color: baseColor, fontWeight: FontWeight.w700, fontSize: 13.5),
      tableBody: const TextStyle(color: baseColor, fontSize: 13.5),
    );
  }
}

Future<void> _copy(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pesan disalin.'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

class _CodeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final text = element.textContent;
    String? language;
    for (final entry in element.attributes.entries) {
      if (entry.key == 'class' && entry.value.startsWith('language-')) {
        language = entry.value.substring('language-'.length);
      }
    }
    if (!text.contains('\n') && language == null) return null;
    return CodeBlock(code: text.trimRight(), language: language);
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: Container(
        width: 8,
        height: 16,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ── User attachment sentinel parsing ────────────────────────────────────

class _UserFileRef {
  final String name;
  final String size;
  final String kind; // text | binary | image
  const _UserFileRef(
      {required this.name, required this.size, required this.kind});
}

class _UserImageRef {
  final String name;
  final String mime;
  final Uint8List bytes;
  const _UserImageRef(
      {required this.name, required this.mime, required this.bytes});
}

class _ParsedUserMessage {
  final String text;
  final List<_UserFileRef> attachments;
  final List<_UserImageRef> images;
  const _ParsedUserMessage(this.text, this.attachments, this.images);
}

final RegExp _fileBlockRe = RegExp(
  r'<<<KIKAI_FILE\s+name="([^"]*)"\s+size="([^"]*)"\s+kind="([^"]*)">>>[\s\S]*?<<<KIKAI_FILE_END>>>',
  multiLine: true,
);

// M44 — sentinel gambar (dari composer). Data = base64.
final RegExp _imageBlockRe = RegExp(
  r'<<<KIKAI_IMAGE\s+mime="([^"]+)"\s+name="([^"]*)"\s+size="[^"]*"\s+data="([^"]+)">>>',
);

_ParsedUserMessage _parseUserContent(String raw) {
  final atts = <_UserFileRef>[];
  final imgs = <_UserImageRef>[];
  var stripped = raw.replaceAllMapped(_imageBlockRe, (m) {
    try {
      imgs.add(_UserImageRef(
        mime: m.group(1) ?? 'image/jpeg',
        name: m.group(2) ?? 'image',
        bytes: base64Decode(m.group(3) ?? ''),
      ));
    } catch (_) {}
    return '';
  });
  stripped = stripped.replaceAllMapped(_fileBlockRe, (m) {
    atts.add(_UserFileRef(
      name: m.group(1) ?? 'file',
      size: m.group(2) ?? '',
      kind: m.group(3) ?? 'binary',
    ));
    return '';
  }).trim();
  return _ParsedUserMessage(stripped, atts, imgs);
}

class _UserImageView extends StatelessWidget {
  final _UserImageRef img;
  const _UserImageView({required this.img});

  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(img.name,
              style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
        ),
        body: Center(
          child: InteractiveViewer(
            child: Image.memory(img.bytes, fit: BoxFit.contain),
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 220,
            maxHeight: 220,
          ),
          child: Image.memory(
            img.bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}

class _FileChipView extends StatelessWidget {
  final _UserFileRef att;
  const _FileChipView({required this.att});

  IconData get _icon {
    switch (att.kind) {
      case 'image':
        return Icons.image_outlined;
      case 'text':
        return Icons.description_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.bubbleUser,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_icon, size: 18, color: Colors.white),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                att.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              if (att.size.isNotEmpty)
                Text(
                  att.size,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────
// M39 — Sources card (mirip Perplexity / ChatGPT): horizontal scroll berisi
// kartu-kartu sumber yang bisa diklik → buka URL di browser.
// ─────────────────────────────────────────────────────────────────────────
/// M40 — Collapsible sources card (mirip ChatGPT: header dengan hitungan
/// + chevron, tap untuk buka/tutup). Default: collapsed.
class _SourcesCard extends StatefulWidget {
  final List<MessageSource> sources;
  const _SourcesCard({required this.sources});

  @override
  State<_SourcesCard> createState() => _SourcesCardState();
}

class _SourcesCardState extends State<_SourcesCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  static String _domain(String url) {
    try {
      final u = Uri.parse(url);
      final h = u.host;
      return h.startsWith('www.') ? h.substring(4) : h;
    } catch (_) {
      return url;
    }
  }

  static String _faviconFor(String url) {
    try {
      final u = Uri.parse(url);
      return 'https://www.google.com/s2/favicons?domain=${u.host}&sz=64';
    } catch (_) {
      return '';
    }
  }

  Future<void> _open(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final sources = widget.sources;
    // Ambil 4 favicon pertama sebagai preview di header saat collapsed.
    final previewCount = sources.length > 4 ? 4 : sources.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded,
                      size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Sumber',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${sources.length}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Preview favicon strip saat collapsed.
                  if (!_expanded)
                    SizedBox(
                      height: 16,
                      child: Stack(
                        children: [
                          for (var i = 0; i < previewCount; i++)
                            Positioned(
                              left: i * 11.0,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: AppColors.divider),
                                ),
                                child: ClipOval(
                                  child: Image.network(
                                    _faviconFor(sources[i].url),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        Container(color: AppColors.divider),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 180),
                    turns: _expanded ? 0.5 : 0.0,
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 20, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: sources.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final s = sources[i];
                        return _SourceChip(
                          index: s.index,
                          title:
                              s.title.isNotEmpty ? s.title : _domain(s.url),
                          domain: _domain(s.url),
                          faviconUrl: _faviconFor(s.url),
                          onTap: () => _open(s.url),
                        );
                      },
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// M40 — Follow-up suggestion chips (mirip ChatGPT). Dirender di bawah
// kartu sumber. Tap chip → kirim sebagai pesan baru.
// ─────────────────────────────────────────────────────────────────────────
class _FollowUpsRow extends StatelessWidget {
  final List<String> followUps;
  final ValueChanged<String> onTap;
  const _FollowUpsRow({required this.followUps, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.auto_awesome_outlined,
                size: 14, color: AppColors.textSecondary),
            SizedBox(width: 6),
            Text(
              'Pertanyaan lanjutan',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final q in followUps) ...[
              _FollowUpChip(text: q, onTap: () => onTap(q)),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ],
    );
  }
}

class _FollowUpChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _FollowUpChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.north_east_rounded,
                size: 16,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _SourceChip extends StatelessWidget {
  final int index;
  final String title;
  final String domain;
  final String faviconUrl;
  final VoidCallback onTap;
  const _SourceChip({
    required this.index,
    required this.title,
    required this.domain,
    required this.faviconUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 190,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: faviconUrl.isEmpty
                          ? Container(color: AppColors.divider)
                          : Image.network(
                              faviconUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: AppColors.divider),
                            ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      domain,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$index',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
