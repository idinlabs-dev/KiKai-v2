import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/creator_submission.dart';
import '../../models/streak_state.dart';
import '../../models/user_entitlements.dart';
import '../../services/auth_service.dart';
import '../../services/creator_mission_service.dart';
import '../../services/ads_service.dart';
import '../../services/notifications_service.dart';
import '../../services/streak_service.dart';

/// M19.1 — Mission Center: user submit link TikTok, lihat status & histori.
///
/// **M21**: ditambah **Daily Check-In card** (klik manual, placeholder
/// rewarded video ad) + tombol shortcut submit misi. Setelah check-in
/// sukses, notifikasi lokal ("Streak +1 hari") juga di-push ke Inbox.
class MissionPage extends StatefulWidget {
  final bool embedded;
  const MissionPage({super.key, this.embedded = false});

  @override
  State<MissionPage> createState() => _MissionPageState();
}

class _MissionPageState extends State<MissionPage> {
  UserEntitlements _ent = const UserEntitlements();
  bool _entLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEnt();
  }

  Future<void> _loadEnt() async {
    final uid = AuthService.instance.current?.uid ?? '';
    final ent = await CreatorMissionService.instance.fetchEntitlements(uid);
    if (!mounted) return;
    setState(() {
      _ent = ent;
      _entLoading = false;
    });
  }

  Future<void> _openSubmit() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => const _SubmitSheet(),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengajuan terkirim. Menunggu review admin.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: !widget.embedded,
        title: const Text('Mission Center'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const _HeroBanner(),
            const SizedBox(height: 16),
            const _DailyCheckInCard(),
            const SizedBox(height: 16),
            if (!_entLoading) _EntitlementsCard(ent: _ent),
            const SizedBox(height: 16),
            const _RewardTiers(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.upload_rounded),
                label: const Text('Ajukan Link Video'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _openSubmit,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Riwayat Pengajuan',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<CreatorSubmission>>(
              stream: CreatorMissionService.instance.mySubmissionsStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final list = snap.data ?? const <CreatorSubmission>[];
                if (list.isEmpty) {
                  return _EmptyBox(
                    text: 'Belum ada pengajuan. Buat konten TikTok, tag '
                        '@kikai, lalu submit linknya di sini.',
                  );
                }
                return Column(
                  children: [for (final s in list) _SubmissionTile(sub: s)],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text('Creator Mission',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                )),
          ]),
          SizedBox(height: 8),
          Text(
            'Buat konten TikTok tentang KiKai, tag @kikai, '
            'lalu klaim reward premium sesuai jumlah views.',
            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _EntitlementsCard extends StatelessWidget {
  final UserEntitlements ent;
  const _EntitlementsCard({required this.ent});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool active) => Container(
          margin: const EdgeInsets.only(right: 8, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? AppColors.success.withOpacity(0.18)
                : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? AppColors.success : AppColors.divider,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              active ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
              size: 14,
              color: active ? AppColors.success : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? AppColors.textPrimary : AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Status Premium Kamu',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 10),
          Wrap(children: [
            chip('No Ads', ent.noAds),
            chip('Priority Response', ent.proActive),
            chip('KiKai Ultra', ent.nvidiaUnlock),
          ]),
        ],
      ),
    );
  }
}

class _RewardTiers extends StatelessWidget {
  const _RewardTiers();
  @override
  Widget build(BuildContext context) {
    Widget tier(String views, String reward, IconData icon, Color color) =>
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(views,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 2),
                  Text(reward,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
            ),
          ]),
        );

    return Column(children: [
      tier('300 Views', 'No Ads Permanen',
          Icons.block_rounded, AppColors.success),
      tier('1,000 Views', 'Priority Response 30 Hari',
          Icons.workspace_premium_rounded, AppColors.warning),
      tier('5,000 Views', 'KiKai Ultra Unlock',
          Icons.bolt_rounded, AppColors.primary),
    ]);
  }
}

class _SubmissionTile extends StatelessWidget {
  final CreatorSubmission sub;
  const _SubmissionTile({required this.sub});

  Color _statusColor() {
    switch (sub.status) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  String _statusLabel() {
    switch (sub.status) {
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      default:
        return 'Menunggu';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.link_rounded, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                sub.videoUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor().withOpacity(0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _statusLabel(),
                style: TextStyle(
                  color: _statusColor(),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Platform: ${sub.platform} • Views: ${sub.views}'
            '${sub.reward != null ? ' • Reward: ${CreatorSubmission.rewardLabel(sub.reward)}' : ''}',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
            ),
          ),
          if ((sub.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Catatan admin: ${sub.notes}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final String text;
  const _EmptyBox({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(text,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
    );
  }
}

class _SubmitSheet extends StatefulWidget {
  const _SubmitSheet();

  @override
  State<_SubmitSheet> createState() => _SubmitSheetState();
}

class _SubmitSheetState extends State<_SubmitSheet> {
  final _url = TextEditingController();
  final _username = TextEditingController();
  String _platform = 'tiktok';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await CreatorMissionService.instance.submit(
        platform: _platform,
        videoUrl: _url.text,
        username: _username.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Ajukan Link Video',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 4),
          const Text(
            'Pastikan konten kamu sudah mention @kikai. '
            'Satu link hanya bisa diajukan satu kali.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          _label('Platform'),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _platform,
                isExpanded: true,
                dropdownColor: AppColors.surfaceElevated,
                style: const TextStyle(color: AppColors.textPrimary),
                items: const [
                  DropdownMenuItem(value: 'tiktok', child: Text('TikTok')),
                  DropdownMenuItem(
                      value: 'instagram', child: Text('Instagram Reels')),
                  DropdownMenuItem(
                      value: 'youtube', child: Text('YouTube Shorts')),
                  DropdownMenuItem(
                      value: 'facebook', child: Text('Facebook Reels')),
                ],
                onChanged: (v) => setState(() => _platform = v ?? 'tiktok'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _label('Username Kreator'),
          const SizedBox(height: 6),
          TextField(
            controller: _username,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _dec('@username'),
          ),
          const SizedBox(height: 12),
          _label('Link Video'),
          const SizedBox(height: 6),
          TextField(
            controller: _url,
            style: const TextStyle(color: AppColors.textPrimary),
            keyboardType: TextInputType.url,
            decoration: _dec('https://www.tiktok.com/...'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Kirim Pengajuan'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String s) => Text(s,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ));

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );
}

/// M21 — Daily Check-In card. Klik tombol → (placeholder) rewarded video
/// ad → StreakService.checkIn → push notifikasi lokal ke Inbox.
class _DailyCheckInCard extends StatefulWidget {
  const _DailyCheckInCard();
  @override
  State<_DailyCheckInCard> createState() => _DailyCheckInCardState();
}

class _DailyCheckInCardState extends State<_DailyCheckInCard> {
  bool _loading = false;

  Future<void> _handleCheckIn() async {
    if (_loading) return;
    if (StreakService.instance.hasCheckedInToday) return;
    setState(() => _loading = true);
    try {
      // M24 — Real AdMob rewarded ad untuk daily check-in.
      final ok = await AdsService.instance.showRewardedCheckin();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Iklan belum selesai. Coba lagi.')),
          );
        }
        return;
      }
      final result = await StreakService.instance.checkIn();
      final count = StreakService.instance.state.count;

      String title = 'Check-in berhasil';
      String body = 'Streak kamu sekarang $count hari. Balik lagi besok!';
      switch (result) {
        case StreakCheckInResult.reachedPremium:
          title = 'KiKai Balanced ter-unlock';
          body = '7 hari berturut! Model Balanced kebuka permanen '
              'selama streak dijaga.';
          break;
        case StreakCheckInResult.premiumMaintained:
          title = 'Streak Premium terjaga';
          body = 'Streak $count hari — model Balanced tetap aktif.';
          break;
        case StreakCheckInResult.broken:
          title = 'Streak reset ke 1';
          body = 'Sempat skip sehari — streak mulai dari awal lagi. '
              'Semangat!';
          break;
        case StreakCheckInResult.firstDay:
          title = 'Selamat datang di Daily Streak';
          body = 'Check-in tiap hari untuk unlock model Balanced di hari ke-7.';
          break;
        case StreakCheckInResult.incremented:
        case StreakCheckInResult.alreadyToday:
          break;
      }

      await NotificationsService.instance.pushLocal(
        id: StreakService.instance.todayNotifId(),
        type: 'streak',
        title: title,
        body: body,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(title)),
        );
        setState(() {}); // refresh tombol → "sudah check-in".
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check-in gagal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = StreakService.instance.hasCheckedInToday;
    final streak = StreakService.instance.state.count;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_fire_department_rounded,
                  color: AppColors.warning),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily Check-In',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      )),
                  SizedBox(height: 2),
                  Text(
                    'Klik tiap hari, tonton iklan singkat, streak jalan.',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            for (int i = 1; i <= StreakState.maxDays; i++)
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                      right: i == StreakState.maxDays ? 0 : 4),
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= streak
                        ? AppColors.primary
                        : AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          Text('$streak / ${StreakState.maxDays} hari',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(done
                  ? Icons.check_circle_rounded
                  : Icons.play_circle_fill_rounded),
              label: Text(done
                  ? 'Sudah Check-In Hari Ini'
                  : (_loading
                      ? 'Memuat iklan…'
                      : 'Check-In Hari Ini (Tonton Iklan)')),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    done ? AppColors.surfaceHigh : AppColors.primary,
                foregroundColor:
                    done ? AppColors.textMuted : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: (done || _loading) ? null : _handleCheckIn,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Catatan: reward video akan aktif otomatis setelah AdMob '
            'terhubung. Sementara pakai placeholder singkat.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
