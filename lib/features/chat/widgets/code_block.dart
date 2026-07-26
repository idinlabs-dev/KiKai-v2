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

  String _extForLang(String lang) {
    switch (lang.toLowerCase()) {
      case 'html':
      case 'xml':
        return 'html';
      case 'css':
        return 'css';
      case 'js':
      case 'javascript':
        return 'js';
      case 'ts':
      case 'typescript':
        return 'ts';
      case 'json':
        return 'json';
      case 'py':
      case 'python':
        return 'py';
      case 'dart':
        return 'dart';
      case 'java':
        return 'java';
      case 'kt':
      case 'kotlin':
        return 'kt';
      case 'swift':
        return 'swift';
      case 'c':
        return 'c';
      case 'cpp':
      case 'c++':
        return 'cpp';
      case 'cs':
      case 'csharp':
        return 'cs';
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
      case 'sh':
      case 'bash':
      case 'shell':
        return 'sh';
      case 'sql':
        return 'sql';
      case 'yml':
      case 'yaml':
        return 'yaml';
      case 'md':
      case 'markdown':
        return 'md';
      default:
        return 'txt';
    }
  }

  Future<void> _downloadCode(BuildContext context) async {
    try {
      final ext = _extForLang(language ?? 'text');
      final ts = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'kikai_snippet_$ts.$ext';

      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      dir ??= await getApplicationDocumentsDirectory();

      final path = '${dir.path}/$fileName';
      final file = File(path);
      await file.writeAsString(code);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tersimpan: $path'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal simpan: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
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
