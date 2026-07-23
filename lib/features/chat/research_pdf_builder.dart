import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// M40 — Renderer sederhana markdown → PDF untuk export laporan riset.
///
/// Mendukung: H1/H2/H3, paragraf, bullet list (- / *), numbered list (1.),
/// blockquote (>), code fence (```), inline bold (**text**) dan italic
/// (*text*). Tabel dan gambar tidak didukung (di-skip / dirender sebagai
/// teks polos).
class ResearchPdfBuilder {
  static Future<pw.Document> build({
    required String title,
    required String markdown,
    required DateTime completedAt,
  }) async {
    final doc = pw.Document(
      title: title,
      author: 'KiKai',
      creator: 'KiKai — Research Report',
    );

    final base = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      italic: pw.Font.helveticaOblique(),
      boldItalic: pw.Font.helveticaBoldOblique(),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 48,
          marginRight: 48,
          marginTop: 56,
          marginBottom: 56,
        ),
        theme: base,
        header: (ctx) => ctx.pageNumber == 1
            ? pw.SizedBox.shrink()
            : pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(bottom: 16),
                child: pw.Text(
                  title,
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColor.fromInt(0xFF9A968C),
                  ),
                ),
              ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            '${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColor.fromInt(0xFF9A968C),
            ),
          ),
        ),
        build: (ctx) => _buildBody(
          title: title,
          markdown: markdown,
          completedAt: completedAt,
        ),
      ),
    );

    return doc;
  }

  static List<pw.Widget> _buildBody({
    required String title,
    required String markdown,
    required DateTime completedAt,
  }) {
    final widgets = <pw.Widget>[];

    // Cover / heading
    widgets.add(pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 26,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
        letterSpacing: -0.3,
      ),
    ));
    widgets.add(pw.SizedBox(height: 6));
    widgets.add(pw.Text(
      'Laporan riset · ${_fmtDate(completedAt)}',
      style: pw.TextStyle(
        fontSize: 10,
        color: PdfColor.fromInt(0xFF9A968C),
        fontWeight: pw.FontWeight.bold,
      ),
    ));
    widgets.add(pw.SizedBox(height: 20));
    widgets.add(pw.Divider(color: PdfColor.fromInt(0xFFE3E0D8), thickness: 0.7));
    widgets.add(pw.SizedBox(height: 12));

    // Parse markdown body (skip H1 pertama supaya tidak double dengan title).
    final body = _stripLeadingH1(markdown);
    _renderMarkdown(body, widgets);
    return widgets;
  }

  static void _renderMarkdown(String md, List<pw.Widget> out) {
    final lines = md.split('\n');
    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      // Code fence
      if (trimmed.startsWith('```')) {
        final buf = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          buf.add(lines[i]);
          i++;
        }
        if (i < lines.length) i++; // consume closing ```
        out.add(_codeBlock(buf.join('\n')));
        out.add(pw.SizedBox(height: 8));
        continue;
      }

      // Empty line → spacing
      if (trimmed.isEmpty) {
        out.add(pw.SizedBox(height: 6));
        i++;
        continue;
      }

      // Headings
      if (trimmed.startsWith('### ')) {
        out.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
          child: pw.Text(
            trimmed.substring(4).trim(),
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
        ));
        i++;
        continue;
      }
      if (trimmed.startsWith('## ')) {
        out.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
          child: pw.Text(
            trimmed.substring(3).trim(),
            style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
          ),
        ));
        i++;
        continue;
      }
      if (trimmed.startsWith('# ')) {
        out.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
          child: pw.Text(
            trimmed.substring(2).trim(),
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
        ));
        i++;
        continue;
      }

      // Blockquote
      if (trimmed.startsWith('> ')) {
        final buf = <String>[trimmed.substring(2)];
        i++;
        while (i < lines.length && lines[i].trim().startsWith('> ')) {
          buf.add(lines[i].trim().substring(2));
          i++;
        }
        out.add(pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 6),
          padding: const pw.EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF3F1EB),
            border: pw.Border(
              left: pw.BorderSide(
                  color: PdfColors.black, width: 2),
            ),
          ),
          child: _richText(buf.join(' '),
              fontSize: 11.5, color: PdfColor.fromInt(0xFF3F3F3F)),
        ));
        continue;
      }

      // Bulleted list
      if (RegExp(r'^[-*]\s+').hasMatch(trimmed)) {
        final items = <String>[];
        while (i < lines.length &&
            RegExp(r'^[-*]\s+').hasMatch(lines[i].trim())) {
          items.add(lines[i].trim().replaceFirst(RegExp(r'^[-*]\s+'), ''));
          i++;
        }
        for (final it in items) {
          out.add(pw.Padding(
            padding: const pw.EdgeInsets.only(left: 4, top: 2, bottom: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 12,
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Text('•',
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Expanded(child: _richText(it, fontSize: 11.5)),
              ],
            ),
          ));
        }
        continue;
      }

      // Numbered list
      final numMatch = RegExp(r'^(\d+)\.\s+').firstMatch(trimmed);
      if (numMatch != null) {
        final items = <String>[];
        while (i < lines.length &&
            RegExp(r'^\d+\.\s+').hasMatch(lines[i].trim())) {
          items.add(lines[i].trim().replaceFirst(RegExp(r'^\d+\.\s+'), ''));
          i++;
        }
        for (var n = 0; n < items.length; n++) {
          out.add(pw.Padding(
            padding: const pw.EdgeInsets.only(left: 4, top: 2, bottom: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 18,
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Text('${n + 1}.',
                      style: pw.TextStyle(
                          fontSize: 11.5, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Expanded(child: _richText(items[n], fontSize: 11.5)),
              ],
            ),
          ));
        }
        continue;
      }

      // Paragraph — gabung baris berturut-turut yang bukan struktur khusus.
      final buf = <String>[trimmed];
      i++;
      while (i < lines.length) {
        final t = lines[i].trim();
        if (t.isEmpty ||
            t.startsWith('#') ||
            t.startsWith('> ') ||
            t.startsWith('```') ||
            RegExp(r'^[-*]\s+').hasMatch(t) ||
            RegExp(r'^\d+\.\s+').hasMatch(t)) {
          break;
        }
        buf.add(t);
        i++;
      }
      out.add(pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: _richText(buf.join(' '), fontSize: 11.5),
      ));
    }
  }

  static pw.Widget _codeBlock(String src) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF3F1EB),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        src,
        style: pw.TextStyle(
          font: pw.Font.courier(),
          fontSize: 9.5,
          lineSpacing: 1.4,
        ),
      ),
    );
  }

  /// Rich text sederhana: dukung **bold**, *italic*, `code`, dan
  /// autolink [text](url) → tampil sebagai teks berwarna.
  static pw.Widget _richText(
    String src, {
    double fontSize = 11.5,
    PdfColor? color,
  }) {
    final spans = <pw.InlineSpan>[];
    final baseStyle = pw.TextStyle(
      fontSize: fontSize,
      color: color ?? PdfColors.black,
      lineSpacing: 1.6,
    );

    // Regex: bold **x**, italic *x*, code `x`, link [t](u).
    final re = RegExp(
      r'(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`|\[[^\]]+\]\([^)]+\))',
    );
    var cursor = 0;
    for (final m in re.allMatches(src)) {
      if (m.start > cursor) {
        spans.add(pw.TextSpan(
            text: src.substring(cursor, m.start), style: baseStyle));
      }
      final tok = m.group(0)!;
      if (tok.startsWith('**')) {
        spans.add(pw.TextSpan(
          text: tok.substring(2, tok.length - 2),
          style: baseStyle.copyWith(fontWeight: pw.FontWeight.bold),
        ));
      } else if (tok.startsWith('*')) {
        spans.add(pw.TextSpan(
          text: tok.substring(1, tok.length - 1),
          style: baseStyle.copyWith(fontStyle: pw.FontStyle.italic),
        ));
      } else if (tok.startsWith('`')) {
        spans.add(pw.TextSpan(
          text: tok.substring(1, tok.length - 1),
          style: baseStyle.copyWith(
            font: pw.Font.courier(),
            fontSize: fontSize - 0.5,
          ),
        ));
      } else if (tok.startsWith('[')) {
        final lm = RegExp(r'^\[([^\]]+)\]\(([^)]+)\)$').firstMatch(tok);
        if (lm != null) {
          spans.add(pw.TextSpan(
            text: lm.group(1),
            style: baseStyle.copyWith(
              color: PdfColor.fromInt(0xFF0B57D0),
              decoration: pw.TextDecoration.underline,
            ),
          ));
        } else {
          spans.add(pw.TextSpan(text: tok, style: baseStyle));
        }
      }
      cursor = m.end;
    }
    if (cursor < src.length) {
      spans.add(pw.TextSpan(text: src.substring(cursor), style: baseStyle));
    }

    return pw.RichText(text: pw.TextSpan(children: spans, style: baseStyle));
  }

  static String _stripLeadingH1(String src) {
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
}
