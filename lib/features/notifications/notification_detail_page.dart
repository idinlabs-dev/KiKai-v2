import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../models/app_notification.dart';

/// M32 — Halaman detail notifikasi.
///
/// Dibuka ketika user tap salah satu tile di [NotificationsScreen].
/// Menampilkan judul, badge sumber, timestamp lengkap, body dalam bentuk
/// scrollable, plus deteksi URL otomatis (misal link update APK dari
/// admin dashboard) sehingga user bisa langsung membukanya di browser.
class NotificationDetailPage extends StatelessWidget {
  final AppNotification item;
  const NotificationDetailPage({super.key, required this.item});

  static final _urlRegex = RegExp(
    r'(https?:\/\/[^\s)>\]}"]+)',
    caseSensitive: false,
  );

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak bisa membuka link.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka link.')),
        );
      }
    }
  }

  IconData get _icon {
    if (item.isBroadcast) return Icons.campaign_rounded;
    switch (item.type) {
      case 'streak':
        return Icons.local_fire_department_rounded;
      case 'mission':
        return Icons.workspace_premium_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color get _color {
    if (item.isBroadcast) return AppColors.primary;
    switch (item.type) {
      case 'streak':
        return AppColors.warning;
      case 'mission':
        return AppColors.success;
      default:
        return AppColors.accent;
    }
  }

  List<InlineSpan> _bodySpans(BuildContext context) {
    final body = item.body.isEmpty ? '(Tidak ada isi pesan.)' : item.body;
    final matches = _urlRegex.allMatches(body).toList();
    if (matches.isEmpty) {
      return [
        TextSpan(
          text: body,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            height: 1.55,
          ),
        ),
      ];
    }
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        spans.add(TextSpan(
          text: body.substring(cursor, m.start),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            height: 1.55,
          ),
        ));
      }
      final url = m.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 15,
          height: 1.55,
          decoration: TextDecoration.underline,
        ),
        recognizer: _TapUrl(() => _open(context, url)),
      ));
      cursor = m.end;
    }
    if (cursor < body.length) {
      spans.add(TextSpan(
        text: body.substring(cursor),
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          height: 1.55,
        ),
      ));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final ts = item.createdAt.millisecondsSinceEpoch == 0
        ? '-'
        : DateFormat('EEEE, dd MMM yyyy • HH:mm')
            .format(item.createdAt.toLocal());
    final urls = _urlRegex
        .allMatches(item.body)
        .map((m) => m.group(0)!)
        .toSet()
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Detail Notifikasi'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _color.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_icon, color: _color, size: 24),
                ),
                const SizedBox(width: 12),
                if (item.isBroadcast)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('ADMIN',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        )),
                  ),
              ]),
              const SizedBox(height: 16),
              Text(
                item.title.isEmpty ? '(tanpa judul)' : item.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(ts,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12.5)),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: SelectableText.rich(
                  TextSpan(children: _bodySpans(context)),
                ),
              ),
              if (urls.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('Tautan cepat',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    )),
                const SizedBox(height: 8),
                ...urls.map((u) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => _open(context, u),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: Text(u,
                            overflow: TextOverflow.ellipsis, maxLines: 1),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.divider),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

TapGestureRecognizer _TapUrl(VoidCallback onTap) {
  return TapGestureRecognizer()..onTap = onTap;
}
