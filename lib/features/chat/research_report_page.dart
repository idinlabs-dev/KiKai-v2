import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import '../../core/theme/app_colors.dart';
import 'research_pdf_builder.dart';

/// M39 — Research Report Page (Gemini-style).
///
/// Layout persis "Laporan Analisis" Gemini:
///   ┌─ Header ────────────────────────────────────────────┐
///   │  ←   {judul-ellipsized}    ≡   ⤴   [ + Buat ▾ ]     │
///   ├─────────────────────────────────────────────────────┤
///   │  # Judul Laporan                                    │
///   │  Pendahuluan / body markdown penuh                  │
///   └─────────────────────────────────────────────────────┘
///
/// Menu "Buat" berisi:
///   Halaman web · Infografis · Kuis · Kartu Tanya Jawab · Ringkasan Audio
///
/// Menu "Share" berisi:
///   Bagikan · Ekspor ke Dokumen · Salin konten
///
/// Export skala ringan (tanpa dep tambahan):
///   - Halaman web  → tulis file .html ke dokumen aplikasi
///   - Ekspor Dok   → tulis file .md ke dokumen aplikasi
///   - Salin konten → clipboard
///   - Bagikan      → clipboard + snackbar (share sistem butuh package
///                    tambahan, sengaja dilewati sesuai request).
class ResearchReportPage extends StatelessWidget {
  final String topic;
  final String markdown;
  final DateTime completedAt;

  const ResearchReportPage({
    super.key,
    required this.topic,
    required this.markdown,
    required this.completedAt,
  });

  String get _title {
    // Coba ambil H1 pertama sebagai judul, kalau tidak ada pakai topic.
    final lines = markdown.split('\n');
    for (final l in lines) {
      final t = l.trim();
      if (t.startsWith('# ')) return t.substring(2).trim();
    }
    final line = topic.trim().split('\n').first.trim();
    if (line.isEmpty) return 'Laporan Riset';
    return line.length <= 80 ? line : '${line.substring(0, 80)}…';
  }

  List<_TocEntry> get _toc {
    final out = <_TocEntry>[];
    for (final raw in markdown.split('\n')) {
      final l = raw.trimLeft();
      if (l.startsWith('### ')) {
        out.add(_TocEntry(level: 3, text: l.substring(4).trim()));
      } else if (l.startsWith('## ')) {
        out.add(_TocEntry(level: 2, text: l.substring(3).trim()));
      } else if (l.startsWith('# ')) {
        out.add(_TocEntry(level: 1, text: l.substring(2).trim()));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _ReportHeader(
              title: _title,
              onBack: () => Navigator.of(context).maybePop(),
              onToc: _toc.isEmpty ? null : () => _openToc(context),
              onShare: () => _openShareSheet(context),
              onCreate: () => _openCreateSheet(context),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Laporan riset · ${_fmtDate(completedAt)}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (markdown.trim().isEmpty)
                      const _EmptyReport()
                    else
                      MarkdownBody(
                        data: _stripLeadingH1(markdown),
                        selectable: true,
                        softLineBreak: true,
                        styleSheet: _reportStyle(),
                        extensionSet: md.ExtensionSet.gitHubFlavored,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────

  String _stripLeadingH1(String src) {
    // Judul sudah dirender terpisah di atas — buang H1 pertama supaya
    // tidak double.
    final lines = src.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final t = lines[i].trim();
      if (t.isEmpty) continue;
      if (t.startsWith('# ')) {
        lines[i] = '';
        return lines.join('\n').trimLeft();
      }
      break;
    }
    return src;
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final l = d.toLocal();
    final hh = l.hour.toString().padLeft(2, '0');
    final mm = l.minute.toString().padLeft(2, '0');
    return '${l.day} ${months[l.month - 1]} ${l.year} · $hh:$mm';
  }

  MarkdownStyleSheet _reportStyle() {
    const baseColor = AppColors.textPrimary;
    return MarkdownStyleSheet(
      p: const TextStyle(
          color: baseColor, fontSize: 15.5, height: 1.7),
      h1: const TextStyle(
          color: baseColor,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          height: 1.25,
          letterSpacing: -0.3),
      h2: const TextStyle(
          color: baseColor,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          height: 1.3,
          letterSpacing: -0.2),
      h3: const TextStyle(
          color: baseColor,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          height: 1.35),
      strong: const TextStyle(
          color: baseColor, fontWeight: FontWeight.w800),
      em: const TextStyle(
          color: baseColor, fontStyle: FontStyle.italic),
      a: const TextStyle(
          color: baseColor,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w600),
      blockSpacing: 14,
      h1Padding: const EdgeInsets.only(top: 12, bottom: 6),
      h2Padding: const EdgeInsets.only(top: 20, bottom: 6),
      h3Padding: const EdgeInsets.only(top: 14, bottom: 4),
      listBullet: const TextStyle(
          color: baseColor, fontSize: 15.5, height: 1.6),
      blockquote: const TextStyle(
          color: AppColors.textSecondary, fontSize: 15, height: 1.6),
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
          color: baseColor,
          fontWeight: FontWeight.w700,
          fontSize: 13.5),
      tableBody:
          const TextStyle(color: baseColor, fontSize: 13.5, height: 1.5),
    );
  }

  // ── Sheets ────────────────────────────────────────────────────────

  void _openToc(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _TocSheet(entries: _toc),
    );
  }

  void _openShareSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _ActionSheet(
        items: [
          _ActionItem(
            icon: Icons.share_outlined,
            label: 'Bagikan',
            onTap: () async {
              Navigator.of(ctx).pop();
              await _copyToClipboard(context,
                  content: markdown,
                  successMsg: 'Konten laporan disalin — tempel untuk dibagikan.');
            },
          ),
          _ActionItem(
            icon: Icons.picture_as_pdf_outlined,
            label: 'Ekspor ke PDF',
            onTap: () async {
              Navigator.of(ctx).pop();
              await _exportPdf(context);
            },
          ),
          _ActionItem(
            icon: Icons.description_outlined,
            label: 'Ekspor Markdown (.md)',
            onTap: () async {
              Navigator.of(ctx).pop();
              await _exportMarkdown(context);
            },
          ),
          _ActionItem(
            icon: Icons.content_copy_rounded,
            label: 'Salin konten',
            onTap: () async {
              Navigator.of(ctx).pop();
              await _copyToClipboard(context,
                  content: markdown, successMsg: 'Konten disalin.');
            },
          ),
        ],
      ),
    );
  }

  void _openCreateSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _ActionSheet(
        title: 'Buat',
        items: [
          _ActionItem(
            icon: Icons.public_rounded,
            label: 'Halaman web',
            subtitle: 'Ekspor sebagai file HTML',
            onTap: () async {
              Navigator.of(ctx).pop();
              await _exportHtml(context);
            },
          ),
          _ActionItem(
            icon: Icons.insights_rounded,
            label: 'Infografis',
            subtitle: 'Ringkasan visual dari heading laporan',
            onTap: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _InfographicPage(
                    title: _title,
                    entries: _toc,
                    completedAt: completedAt,
                  ),
                ),
              );
            },
          ),
          _ActionItem(
            icon: Icons.quiz_outlined,
            label: 'Kuis',
            subtitle: 'Segera hadir',
            onTap: () {
              Navigator.of(ctx).pop();
              _snack(context, 'Kuis — segera hadir.');
            },
          ),
          _ActionItem(
            icon: Icons.style_outlined,
            label: 'Kartu Tanya Jawab',
            subtitle: 'Segera hadir',
            onTap: () {
              Navigator.of(ctx).pop();
              _snack(context, 'Kartu Tanya Jawab — segera hadir.');
            },
          ),
          _ActionItem(
            icon: Icons.headphones_rounded,
            label: 'Ringkasan Audio',
            subtitle: 'Segera hadir',
            onTap: () {
              Navigator.of(ctx).pop();
              _snack(context, 'Ringkasan Audio — segera hadir.');
            },
          ),
        ],
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────

  Future<void> _copyToClipboard(
    BuildContext context, {
    required String content,
    required String successMsg,
  }) async {
    await Clipboard.setData(ClipboardData(text: content));
    _snack(context, successMsg);
  }

  /// M40 — Export laporan riset ke PDF. Konten markdown dirender via
  /// [ResearchPdfBuilder]; hasilnya disimpan ke folder dokumen aplikasi
  /// dan langsung dibuka share sheet native lewat `printing`.
  Future<void> _exportPdf(BuildContext context) async {
    try {
      final doc = await ResearchPdfBuilder.build(
        title: _title,
        markdown: markdown,
        completedAt: completedAt,
      );
      final bytes = await doc.save();
      final dir = await getApplicationDocumentsDirectory();
      final safe = _safeFileName(_title);
      final filename = 'kikai-research-$safe-${_stamp()}.pdf';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      _snack(context, 'PDF disimpan: ${file.path}');
      // Buka share sheet supaya user bisa langsung kirim / simpan ulang.
      try {
        await Printing.sharePdf(bytes: bytes, filename: filename);
      } catch (_) {
        // Share sheet opsional; abaikan bila platform tidak mendukung.
      }
    } catch (e) {
      _snack(context, 'Gagal ekspor PDF: $e');
    }
  }

  Future<void> _exportMarkdown(BuildContext context) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final safe = _safeFileName(_title);
      final file =
          File('${dir.path}/kikai-research-$safe-${_stamp()}.md');
      await file.writeAsString(markdown, flush: true);
      _snack(context, 'Disimpan: ${file.path}');
    } catch (e) {
      _snack(context, 'Gagal ekspor: $e');
    }
  }

  Future<void> _exportHtml(BuildContext context) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final safe = _safeFileName(_title);
      final file =
          File('${dir.path}/kikai-research-$safe-${_stamp()}.html');
      final html = _renderHtml(_title, markdown, completedAt);
      await file.writeAsString(html, flush: true);
      _snack(context, 'Halaman web disimpan: ${file.path}');
    } catch (e) {
      _snack(context, 'Gagal ekspor HTML: $e');
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  static String _safeFileName(String s) {
    final cleaned = s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return cleaned.isEmpty
        ? 'laporan'
        : cleaned.substring(0, cleaned.length > 40 ? 40 : cleaned.length);
  }

  static String _stamp() {
    final d = DateTime.now();
    return '${d.year}${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}-'
        '${d.hour.toString().padLeft(2, '0')}'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  static String _renderHtml(
      String title, String markdown, DateTime completedAt) {
    final body = md.markdownToHtml(
      markdown,
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );
    final esc = const HtmlEscape().convert(title);
    return '''<!doctype html>
<html lang="id">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$esc</title>
<style>
  :root { color-scheme: light; }
  html, body {
    margin: 0; padding: 0;
    background: #F5F3EE; color: #0A0A0A;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    -webkit-font-smoothing: antialiased;
  }
  main {
    max-width: 720px;
    margin: 0 auto;
    padding: 48px 24px 80px;
  }
  h1, h2, h3 { letter-spacing: -0.02em; line-height: 1.25; }
  h1 { font-size: 32px; margin: 0 0 6px; font-weight: 800; }
  h2 { font-size: 22px; margin: 32px 0 8px; font-weight: 800; }
  h3 { font-size: 18px; margin: 22px 0 6px; font-weight: 700; }
  p, li { font-size: 16px; line-height: 1.7; }
  a { color: #0A0A0A; }
  .meta { color: #9A968C; font-size: 13px; font-weight: 600; margin-bottom: 24px; }
  blockquote {
    margin: 16px 0; padding: 10px 14px;
    background: #ECEAE3; border-left: 3px solid #0A0A0A;
    border-radius: 8px;
  }
  pre, code {
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    background: #ECEAE3;
  }
  pre { padding: 12px; border-radius: 10px; overflow: auto; font-size: 13px; }
  code { padding: 1px 5px; border-radius: 4px; font-size: 0.9em; }
  pre code { padding: 0; background: transparent; }
  table { border-collapse: collapse; width: 100%; margin: 12px 0; }
  th, td { border: 1px solid #E3E0D8; padding: 8px 10px; font-size: 14px; }
  th { background: #ECEAE3; text-align: left; }
  hr { border: none; border-top: 1px solid #E3E0D8; margin: 32px 0; }
</style>
</head>
<body>
<main>
  <h1>$esc</h1>
  <div class="meta">Laporan riset · ${_fmtDate(completedAt)}</div>
  $body
</main>
</body>
</html>
''';
  }
}

// ── Header ───────────────────────────────────────────────────────────

class _ReportHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback? onToc;
  final VoidCallback onShare;
  final VoidCallback onCreate;

  const _ReportHeader({
    required this.title,
    required this.onBack,
    required this.onToc,
    required this.onShare,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      color: AppColors.background,
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textPrimary),
            tooltip: 'Kembali',
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (onToc != null)
            IconButton(
              onPressed: onToc,
              icon: const Icon(Icons.format_list_bulleted_rounded,
                  color: AppColors.textPrimary),
              tooltip: 'Daftar isi',
            ),
          IconButton(
            onPressed: onShare,
            icon: const Icon(Icons.ios_share_rounded,
                color: AppColors.textPrimary),
            tooltip: 'Bagikan',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onCreate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded,
                          size: 16, color: AppColors.surface),
                      SizedBox(width: 4),
                      Text(
                        'Buat',
                        style: TextStyle(
                          color: AppColors.surface,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          size: 18, color: AppColors.surface),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action sheet (Buat / Share) ──────────────────────────────────────

class _ActionItem {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  const _ActionItem({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });
}

class _ActionSheet extends StatelessWidget {
  final String? title;
  final List<_ActionItem> items;
  const _ActionSheet({this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Text(
                  title!,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            for (final it in items) _ActionRow(item: it),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final _ActionItem item;
  const _ActionRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Icon(item.icon,
                    size: 20, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── TOC sheet ────────────────────────────────────────────────────────

class _TocEntry {
  final int level;
  final String text;
  const _TocEntry({required this.level, required this.text});
}

class _TocSheet extends StatelessWidget {
  final List<_TocEntry> entries;
  const _TocSheet({required this.entries});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Daftar isi',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: entries.length,
                itemBuilder: (_, i) {
                  final e = entries[i];
                  return Padding(
                    padding: EdgeInsets.only(
                      left: (e.level - 1) * 14.0,
                      top: 8,
                      bottom: 8,
                    ),
                    child: Text(
                      e.text,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: e.level == 1 ? 15.5 : 14,
                        fontWeight: e.level == 1
                            ? FontWeight.w800
                            : FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────

class _EmptyReport extends StatelessWidget {
  const _EmptyReport();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: const Text(
        'Laporan masih kosong. Jalankan riset dari layar chat, '
        'lalu buka kartu "Riset ..." untuk melihat laporan penuh di sini.',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }
}

// ── Infographic view (visualisasi ringkas heading laporan) ───────────

class _InfographicPage extends StatelessWidget {
  final String title;
  final List<_TocEntry> entries;
  final DateTime completedAt;

  const _InfographicPage({
    required this.title,
    required this.entries,
    required this.completedAt,
  });

  @override
  Widget build(BuildContext context) {
    final h2 = entries.where((e) => e.level == 2).toList();
    final source = h2.isNotEmpty ? h2 : entries;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: AppColors.textPrimary),
                  ),
                  const Expanded(
                    child: Text(
                      'Infografis',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Infografis · ${ResearchReportPage._fmtDate(completedAt)}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (source.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: const Text(
                        'Laporan belum punya heading yang bisa '
                        'dijadikan blok infografis.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    )
                  else
                    for (var i = 0; i < source.length; i++) ...[
                      _InfographicTile(
                        index: i + 1,
                        text: source[i].text,
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfographicTile extends StatelessWidget {
  final int index;
  final String text;
  const _InfographicTile({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              index.toString().padLeft(2, '0'),
              style: const TextStyle(
                color: AppColors.surface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
