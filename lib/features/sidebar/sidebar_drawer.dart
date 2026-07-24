import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../models/chat_thread.dart';
import '../chat/chat_controller.dart';
import 'thread_tile.dart';

/// Sidebar drawer M2 — daftar thread, tombol "+ New Chat", footer settings.
class SidebarDrawer extends StatelessWidget {
  final ChatController controller;
  final VoidCallback? onSettingsTap;

  const SidebarDrawer({
    super.key,
    required this.controller,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      width: 300,
      child: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final threads = controller.threads;
            final currentId = controller.currentThread?.id;

            final pinned = threads.where((t) => t.pinned).toList();
            final others = threads.where((t) => !t.pinned).toList();

            return Column(
              children: [
                _Header(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('New Chat'),
                      onPressed: () {
                        controller.newDraft();
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: controller.threadsLoading && threads.isEmpty
                      ? const _LoadingList()
                      : threads.isEmpty
                          ? const _EmptyList()
                          : ListView(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              children: [
                                if (pinned.isNotEmpty) ...[
                                  const _SectionLabel('Pinned'),
                                  ...pinned.map((t) => _tile(context, t, currentId)),
                                  const SizedBox(height: 8),
                                ],
                                if (others.isNotEmpty) ...[
                                  if (pinned.isNotEmpty)
                                    const _SectionLabel('Recent'),
                                  ...others.map(
                                      (t) => _tile(context, t, currentId)),
                                ],
                              ],
                            ),
                ),
                const Divider(height: 1, color: AppColors.divider),
                _Footer(onSettingsTap: onSettingsTap),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, ChatThread t, String? currentId) {
    return ThreadTile(
      thread: t,
      selected: t.id == currentId,
      onTap: () async {
        await controller.openThread(t.id);
        if (context.mounted) Navigator.of(context).pop();
      },
      onRename: () => _promptRename(context, t),
      onDelete: () => _confirmDelete(context, t),
      onTogglePin: () => controller.togglePin(t.id),
    );
  }

  Future<void> _promptRename(BuildContext context, ChatThread t) async {
    final ctrl = TextEditingController(text: t.title);
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Ubah judul'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(hintText: 'Judul percakapan'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (res != null) await controller.renameThread(t.id, res);
  }

  Future<void> _confirmDelete(BuildContext context, ChatThread t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Hapus percakapan?'),
        content: Text(
            'Percakapan "${t.title}" dan semua pesannya akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) await controller.deleteThread(t.id);
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Text(
              'K',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                AppConfig.appName,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              Text(
                'v${AppConfig.appVersion}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined,
                size: 42, color: AppColors.textMuted.withOpacity(0.6)),
            const SizedBox(height: 12),
            const Text(
              'Belum ada percakapan.\nTap "New Chat" untuk mulai.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final VoidCallback? onSettingsTap;
  const _Footer({this.onSettingsTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSettingsTap ??
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Settings & Profile aktif di M5.'),
              ),
            );
          },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.surfaceHigh,
              child: Icon(Icons.person_outline,
                  size: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Settings & Profile',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.settings_outlined,
                size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Format waktu relatif untuk ThreadTile.
String formatRelative(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inSeconds < 60) return 'baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  return DateFormat('d MMM yyyy').format(dt);
}
