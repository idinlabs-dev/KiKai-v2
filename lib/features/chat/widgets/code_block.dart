import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_colors.dart';

/// KiKai — blok kode terang (monokrom) dengan syntax highlight + copy + unduh.
class CodeBlock extends StatelessWidget {
  final String code;
  final String? language;

  const CodeBlock({super.key, required this.code, this.language});

  // Map bahasa → ekstensi file yg wajar buat unduhan.
  String _extFor(String lang) {
    switch (lang) {
      case 'html':
      case 'xml':
        return 'html';
      case 'js':
      case 'javascript':
        return 'js';
      case 'ts':
      case 'typescript':
        return 'ts';
      case 'jsx':
        return 'jsx';
      case 'tsx':
        return 'tsx';
      case 'py':
      case 'python':
        return 'py';
      case 'dart':
        return 'dart';
      case 'java':
        return 'java';
      case 'kotlin':
      case 'kt':
        return 'kt';
      case 'swift':
        return 'swift';
      case 'go':
        return 'go';
      case 'rs':
      case 'rust':
        return 'rs';
      case 'php':
        return 'php';
      case 'rb':
      case 'ruby':
        return 'rb';
      case 'c':
        return 'c';
      case 'cpp':
      case 'c++':
        return 'cpp';
      case 'cs':
      case 'csharp':
        return 'cs';
      case 'css':
        return 'css';
      case 'scss':
        return 'scss';
      case 'json':
        return 'json';
      case 'yaml':
      case 'yml':
        return 'yaml';
      case 'md':
      case 'markdown':
        return 'md';
      case 'sh':
      case 'bash':
      case 'shell':
        return 'sh';
      case 'sql':
        return 'sql';
      default:
        return 'txt';
    }
  }

  Future<void> _downloadCode(BuildContext context) async {
    try {
      final lang = (language ?? 'text').toLowerCase();
      final ext = _extFor(lang);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final filename = 'kikai_snippet_$ts.$ext';

      // Coba folder Download publik di Android dulu, fallback ke external
      // storage app-scoped, terakhir ke temp dir.
      Directory? dir;
      if (Platform.isAndroid) {
        const publicDownload = '/storage/emulated/0/Download';
        final d = Directory(publicDownload);
        if (await d.exists()) dir = d;
      }
      dir ??= await getExternalStorageDirectory();
      dir ??= await getTemporaryDirectory();

      final file = File('${dir.path}/$filename');
      await file.writeAsString(code);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tersimpan: ${file.path}'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Text(
                  (language ?? 'text').toLowerCase(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Kode disalin.'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Icon(Icons.copy_rounded,
                        size: 15, color: AppColors.textSecondary),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _downloadCode(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Icon(Icons.file_download_outlined,
                        size: 16, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(4),
            child: HighlightView(
              code,
              language: (language ?? 'plaintext').toLowerCase(),
              theme: githubTheme,
              padding: const EdgeInsets.all(12),
              textStyle: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
