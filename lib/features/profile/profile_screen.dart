import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../models/streak_state.dart';
import '../../services/streak_service.dart';
import '../../services/auth_service.dart';
import '../chat/chat_controller.dart';
import '../settings/settings_screen.dart';

/// M5 — Profile screen dengan **Daily Login Streak Premium**.
///
/// Fitur utama:
/// - Header profil placeholder (avatar + nama lokal — sinkron login cloud
///   masuk di milestone berikutnya).
/// - Kartu streak 7-hari (grid harian + reward) + progress bar.
/// - Badge status **Premium Mode** (aktif bila streak ≥ 7).
/// - Section rotasi API key ringkas (informational, tidak expose full key).
class ProfileScreen extends StatefulWidget {
  final ChatController? controller;
  const ProfileScreen({super.key, this.controller});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final StreakService _streak = StreakService.instance;

  @override
  void initState() {
    super.initState();
    _streak.addListener(_onChange);
    // Pastikan sudah loaded (aman kalau sudah di-load oleh main).
    _streak.load();
  }

  @override
  void dispose() {
    _streak.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = _streak.state;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.controller == null,
        title: const Text('Profile'),
        actions: [
          if (widget.controller != null)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(controller: widget.controller!),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const _ProfileHeader(),
            const SizedBox(height: 20),
            _StreakCard(state: s),
            const SizedBox(height: 16),
            _PremiumStatusCard(active: s.premiumActive),
            const SizedBox(height: 16),
            const _DonationCard(),
            const SizedBox(height: 16),
            const _AboutCard(),
          ],
        ),
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.35),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            'K',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AuthService.instance.current?.name.isNotEmpty == true
                    ? AuthService.instance.current!.name
                    : 'Kamu',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Pengguna ${AppConfig.appName}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Streak Card ─────────────────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  final StreakState state;
  const _StreakCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final count = state.count;
    final max = StreakState.maxDays;
    final progress = (count / max).clamp(0.0, 1.0);
    final lastLabel = state.lastCheckInDate == null
        ? 'Belum ada check-in'
        : 'Check-in terakhir: ${DateFormat('d MMM yyyy').format(state.lastCheckInDate!)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: AppColors.accent, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Daily Login Streak',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count / $max',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DaysGrid(count: count),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceHigh,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            lastLabel,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
          ),
          const SizedBox(height: 4),
          const Text(
            'Buka aplikasi setiap hari agar streak tidak putus. '
            'Skip 1 hari → streak reset ke 0.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _DaysGrid extends StatelessWidget {
  final int count;
  const _DaysGrid({required this.count});

  @override
  Widget build(BuildContext context) {
    const total = StreakState.maxDays;
    return Row(
      children: List.generate(total, (i) {
        final day = i + 1;
        final done = day <= count;
        final isReward = day == total;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
            child: _DayCell(day: day, done: done, isReward: isReward),
          ),
        );
      }),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool done;
  final bool isReward;
  const _DayCell(
      {required this.day, required this.done, required this.isReward});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final IconData icon;

    if (isReward) {
      bg = done ? AppColors.accent : AppColors.surfaceHigh;
      fg = done ? Colors.white : AppColors.textMuted;
      icon = Icons.card_giftcard_rounded;
    } else {
      bg = done ? AppColors.primary : AppColors.surfaceHigh;
      fg = done ? Colors.white : AppColors.textMuted;
      icon = done ? Icons.check_rounded : Icons.circle_outlined;
    }

    return Column(
      children: [
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: done ? Colors.transparent : AppColors.divider,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: fg),
        ),
        const SizedBox(height: 4),
        Text(
          isReward ? 'R' : 'H$day',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: done ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

// ── Premium Status ──────────────────────────────────────────────────────

class _PremiumStatusCard extends StatelessWidget {
  final bool active;
  const _PremiumStatusCard({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: active
            ? AppColors.brandGradient
            : const LinearGradient(
                colors: [AppColors.surfaceElevated, AppColors.surfaceElevated],
              ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? Colors.transparent : AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withOpacity(0.18)
                  : AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              active
                  ? Icons.workspace_premium_rounded
                  : Icons.lock_outline_rounded,
              color: active ? Colors.white : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? 'Premium Mode Aktif' : 'Premium Mode Terkunci',
                  style: TextStyle(
                    color: active ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  active
                      ? 'Bebas iklan · pengalaman AI lebih nyaman.'
                      : 'Login 7 hari berturut-turut untuk membukanya.',
                  style: TextStyle(
                    color: active
                        ? Colors.white.withOpacity(0.9)
                        : AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



// ── About ───────────────────────────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tentang aplikasi',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${AppConfig.appName} · v${AppConfig.appVersion} (build ${AppConfig.appBuild})',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dialog helpers ──────────────────────────────────────────────────────

/// Ditampilkan saat user pertama kali mencapai 7-day streak.
Future<void> showReachedPremiumDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      title: const Row(
        children: [
          Text('Selamat!'),
        ],
      ),
      content: const Text(
        'Kamu mendapatkan:\n\n'
        '- Premium Mode\n'
        '- Bebas iklan\n'
        '- Pengalaman AI lebih nyaman\n\n'
        'Tetap login setiap hari agar status premium tidak hilang.',
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Mantap'),
        ),
      ],
    ),
  );
}

/// Ditampilkan saat streak putus (gap ≥ 1 hari).
Future<void> showStreakBrokenDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      title: const Text('Streak terputus!'),
      content: const Text(
        'Kamu tidak membuka aplikasi selama 1 hari.\n\n'
        'Status premium telah dicabut. Silakan mulai kembali dari hari '
        'pertama — buka aplikasi setiap hari untuk meraihnya lagi.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Mengerti'),
        ),
      ],
    ),
  );
}

// ── Donation card (M43) ─────────────────────────────────────────────────

class _DonationCard extends StatelessWidget {
  const _DonationCard();

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: const [
              Icon(Icons.volunteer_activism_outlined,
                  color: AppColors.textPrimary, size: 20),
              SizedBox(width: 8),
              Text(
                'Dukung KiKai',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Kalau KiKai ngebantu kamu, boleh banget kirim donasi lewat '
            'QRIS di bawah. Scan pakai app bank / e-wallet apa aja — '
            'nominal bebas. Makasih banyak, bro.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _showFullQr(context),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/donation/qris.jpeg',
                  width: 220,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Tap QR untuk perbesar · NMID ID1025374103220',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullQr(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'QRIS · Donasi KiKai',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Image.asset(
                'assets/donation/qris.jpeg',
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
