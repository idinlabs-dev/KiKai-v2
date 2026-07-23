import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/creator_submission.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/creator_mission_service.dart';

/// M19.4 — Admin dashboard: review Creator Mission submissions.
///
/// Route ini hanya diekspos dari Settings kalau
/// `AdminService.instance.isAdmin() == true`. Rules Firestore juga
/// menegakkan role di server-side.
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Admin — Creator Mission'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Cari username / link / uid',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<CreatorSubmission>>(
                stream: CreatorMissionService.instance.pendingStream(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var list = snap.data ?? const <CreatorSubmission>[];
                  if (_query.isNotEmpty) {
                    list = list
                        .where((s) =>
                            s.username.toLowerCase().contains(_query) ||
                            s.videoUrl.toLowerCase().contains(_query) ||
                            s.uid.toLowerCase().contains(_query))
                        .toList();
                  }
                  if (list.isEmpty) {
                    return const Center(
                      child: Text(
                        'Tidak ada pengajuan pending.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _AdminReviewCard(sub: list[i]),
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

class _AdminReviewCard extends StatefulWidget {
  final CreatorSubmission sub;
  const _AdminReviewCard({required this.sub});

  @override
  State<_AdminReviewCard> createState() => _AdminReviewCardState();
}

class _AdminReviewCardState extends State<_AdminReviewCard> {
  final _views = TextEditingController();
  final _notes = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _views.text = widget.sub.views.toString();
  }

  @override
  void dispose() {
    _views.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _act(bool approve) async {
    if (!AdminService.instance.isAdminCached) {
      final ok = await AdminService.instance.isAdmin();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Akses admin ditolak.')),
          );
        }
        return;
      }
    }
    setState(() => _busy = true);
    try {
      final adminUid = AuthService.instance.current?.uid ?? '';
      final views = int.tryParse(_views.text.trim()) ?? widget.sub.views;
      await CreatorMissionService.instance.review(
        submission: widget.sub,
        approve: approve,
        adminUid: adminUid,
        overrideViews: views,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve
              ? 'Disetujui — reward diterapkan.'
              : 'Pengajuan ditolak.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sub;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('User: ${s.username.isEmpty ? s.uid : s.username}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 2),
          Text('UID: ${s.uid}',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              )),
          const SizedBox(height: 8),
          Text('Platform: ${s.platform}',
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          SelectableText(
            s.videoUrl,
            style: const TextStyle(color: AppColors.primary, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _views,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _dec('Verified views'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _notes,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _dec('Catatan (opsional)'),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _act(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _busy ? null : () => _act(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Approve'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        filled: true,
        fillColor: AppColors.surfaceHigh,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      );
}
