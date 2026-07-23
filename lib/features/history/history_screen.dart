import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../models/chat_message.dart';
import '../../models/chat_thread.dart';
import '../../services/history_service.dart';
import '../chat/chat_controller.dart';
import '../shared/native_ad_tile.dart';

/// M6 — History tab: daftar thread persisted (sqflite) dengan snippet
/// pesan terakhir, timestamp relatif, dan badge jumlah pesan. Tap tile
/// → buka thread di tab Chats (via `onOpenThread` callback ke shell).
class HistoryScreen extends StatefulWidget {
  final ChatController controller;
  final VoidCallback onOpenThread;

  const HistoryScreen({
    super.key,
    required this.controller,
    required this.onOpenThread,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final Map<String, _ThreadSummary> _summaries = {};
  final TextEditingController _searchCtrl = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSummaries());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    _loadSummaries();
  }

  Future<void> _loadSummaries() async {
    for (final t in widget.controller.threads) {
      if (_summaries.containsKey(t.id)) continue;
      final msgs = await HistoryService.instance.listMessages(t.id);
      if (!mounted) return;
      _summaries[t.id] = _ThreadSummary(
        count: msgs.length,
        snippet: _snippetFrom(msgs),
      );
      setState(() {});
    }
  }

  String _snippetFrom(List<ChatMessage> msgs) {
    if (msgs.isEmpty) return 'Belum ada pesan.';
    final last = msgs.last;
    final text = last.content.replaceAll('\n', ' ').trim();
    return text.isEmpty ? '(pesan kosong)' : text;
  }

  Future<void> _openThread(ChatThread t) async {
    await widget.controller.openThread(t.id);
    widget.onOpenThread();
  }

  Future<void> _newChat() async {
    widget.controller.newDraft();
    widget.onOpenThread();
  }

  Future<void> _confirmDelete(ChatThread t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Hapus percakapan?'),
        content: Text('"${t.title}" akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.controller.deleteThread(t.id);
      _summaries.remove(t.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _rename(ChatThread t) async {
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
          decoration: const InputDecoration(hintText: 'Judul baru'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (res != null && res.isNotEmpty) {
      await widget.controller.renameThread(t.id, res);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final all = widget.controller.threads;
            final threads = _query.isEmpty
                ? all
                : all
                    .where((t) =>
                        t.title.toLowerCase().contains(_query.toLowerCase()))
                    .toList();
            return Column(
              children: [
                _Header(
                  searching: _searching,
                  searchCtrl: _searchCtrl,
                  onSearchTap: () => setState(() => _searching = !_searching),
                  onSearchChanged: (v) => setState(() => _query = v),
                ),
                Expanded(
                  child: threads.isEmpty
                      ? const _EmptyHistory()
                      : Stack(
                          children: [
                            Builder(builder: (_) {
                              // M32 — sisipkan native ad tiap 4 thread.
                              const int adEvery = 4;
                              final adCount = threads.length ~/ adEvery;
                              final total = threads.length + adCount;
                              return ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 4, 16, 100),
                                itemCount: total,
                                itemBuilder: (_, i) {
                                  const block = adEvery + 1;
                                  if (i % block == adEvery) {
                                    return const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 8),
                                      child: NativeAdTile(),
                                    );
                                  }
                                  final idx = i - (i ~/ block);
                                  if (idx >= threads.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final t = threads[idx];
                                  final s = _summaries[t.id];
                                  return _ThreadCard(
                                    thread: t,
                                    summary: s,
                                    onTap: () => _openThread(t),
                                    onMore: () => _showTileMenu(t),
                                  );
                                },
                              );
                            }),
                            Positioned(
                              right: 20,
                              bottom: 24,
                              child: _NewChatFab(onTap: _newChat),
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showTileMenu(ChatThread t) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined,
                  color: AppColors.textPrimary),
              title: const Text('Ubah judul'),
              onTap: () {
                Navigator.pop(ctx);
                _rename(t);
              },
            ),
            ListTile(
              leading: Icon(
                t.pinned
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
                color: t.pinned ? AppColors.accent : AppColors.textPrimary,
              ),
              title: Text(t.pinned ? 'Lepas sematan' : 'Sematkan'),
              onTap: () async {
                Navigator.pop(ctx);
                await widget.controller.togglePin(t.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.danger),
              title: const Text('Hapus',
                  style: TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(t);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ThreadSummary {
  final int count;
  final String snippet;
  const _ThreadSummary({required this.count, required this.snippet});
}

class _Header extends StatelessWidget {
  final bool searching;
  final TextEditingController searchCtrl;
  final VoidCallback onSearchTap;
  final ValueChanged<String> onSearchChanged;

  const _Header({
    required this.searching,
    required this.searchCtrl,
    required this.onSearchTap,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  gradient: AppColors.avatarGradient,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(1),
                child: ClipOval(
                  child: Image.asset(
                    'assets/mascot/claude_ai_mascot.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'KiKai ',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              ShaderMask(
                shaderCallback: (r) =>
                    AppColors.brandGradient.createShader(r),
                child: const Text(
                  'AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Chat History',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Material(
                color: AppColors.surfaceElevated,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onSearchTap,
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Icon(
                      searching ? Icons.close_rounded : Icons.search_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (searching) ...[
            const SizedBox(height: 12),
            TextField(
              controller: searchCtrl,
              onChanged: onSearchChanged,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Cari percakapan…',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off_rounded,
                size: 56, color: AppColors.textMuted.withOpacity(0.6)),
            const SizedBox(height: 16),
            const Text(
              'Belum ada percakapan',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Mulai chat baru di tab Chats.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  final ChatThread thread;
  final _ThreadSummary? summary;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const _ThreadCard({
    required this.thread,
    required this.summary,
    required this.onTap,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    gradient: AppColors.avatarGradient,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(1.5),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/mascot/claude_ai_mascot.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.surfaceHigh,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (thread.pinned) ...[
                            const Icon(Icons.push_pin_rounded,
                                size: 14, color: AppColors.accent),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              thread.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          InkResponse(
                            onTap: onMore,
                            radius: 18,
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.more_vert_rounded,
                                  size: 18, color: AppColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary?.snippet ?? '…',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            _formatRelative(thread.updatedAt),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11.5,
                            ),
                          ),
                          const Spacer(),
                          if (summary != null && summary!.count > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.4),
                                ),
                              ),
                              child: Text(
                                '${summary!.count}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatRelative(DateTime dt) {
  final now = DateTime.now();
  final local = dt.toLocal();
  final diff = now.difference(local);
  final time = DateFormat('HH:mm').format(local);
  if (diff.inMinutes < 1) return 'Baru saja';
  if (diff.inHours < 1) return '${diff.inMinutes} mnt lalu';
  if (_sameDay(local, now)) return 'Hari ini, $time';
  if (_sameDay(local, now.subtract(const Duration(days: 1)))) {
    return 'Kemarin, $time';
  }
  if (diff.inDays < 7) return '${diff.inDays} hari lalu, $time';
  return DateFormat('d MMM yyyy').format(local);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _NewChatFab extends StatelessWidget {
  final VoidCallback onTap;
  const _NewChatFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.avatarGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 58,
            height: 58,
            child: Icon(Icons.add_rounded, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}

// Suppress unused import warning kalau AppConfig belum dipakai
// (dipakai di komponen lain, tetap butuh untuk konsistensi impor).
// ignore: unused_element
const _appName = AppConfig.appName;