import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../app.dart' show kThemeMode;
import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/device_session_service.dart';
import '../../services/history_service.dart';
import '../../services/social_auth_service.dart';
import '../chat/chat_controller.dart';
import '../chat/widgets/model_selector.dart';
import '../mission/mission_page.dart';
import '../mission/vip_donation_page.dart';
import '../admin/admin_dashboard.dart';
import '../about/about_page.dart';
import '../about/privacy_policy_page.dart';
import '../../services/admin_service.dart';

/// M6 — Settings screen: profile card, preferences (Theme / Language /
/// AI Model), Clear Chat History (danger), About section.
class SettingsScreen extends StatefulWidget {
  final ChatController controller;
  const SettingsScreen({super.key, required this.controller});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _language = 'Bahasa Indonesia';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    // M19.4 — reveal admin dashboard entry kalau user punya
    // flag is_admin=true di Firestore.
    AdminService.instance.isAdmin().then((v) {
      if (!mounted) return;
      if (v != _isAdmin) setState(() => _isAdmin = v);
    });
  }

  Future<void> _clearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Hapus semua riwayat?'),
        content: const Text(
          'Semua percakapan akan dihapus permanen dari perangkat.',
        ),
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
    if (ok != true) return;
    await HistoryService.instance.clearAll();
    await widget.controller.refreshThreads();
    widget.controller.newDraft();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Semua riwayat dihapus.')),
    );
  }

  Future<void> _pickModel() async {
    final chosen = await showModelSelector(
      context: context,
      current: widget.controller.model,
    );
    if (chosen != null) widget.controller.setModel(chosen);
  }

  Future<void> _pickLanguage() async {
    final options = ['Bahasa Indonesia', 'English', '日本語'];
    final res = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in options)
              ListTile(
                title: Text(o),
                trailing: o == _language
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, o),
              ),
          ],
        ),
      ),
    );
    if (res != null) setState(() => _language = res);
  }

  /// M18.1 — Sign out dari semua provider (email/pass, Google, Facebook,
  /// Firebase) + release klaim single-device di Firestore. AuthGate akan
  /// otomatis balik ke LoginScreen begitu session lokal kosong.
  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Kamu bakal balik ke halaman login. Riwayat chat lokal tetap ada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final uid = AuthService.instance.current?.uid ?? '';
    // Release klaim device di Firestore (kalau device ini masih owner).
    if (uid.isNotEmpty) {
      await DeviceSessionService.instance.release(uid);
    }
    await SocialAuthService.instance.signOut();
    await AuthService.instance.signOut();
    if (!mounted) return;
    // Pop ke root — AuthGate re-evaluate lalu tampilkan LoginScreen.
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) => CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: const [
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Settings',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      SizedBox(width: 40),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const _SectionLabel('PREFERENCES'),
                      const SizedBox(height: 8),
                      _CardGroup(children: [
                        _ThemeRow(
                          value: kThemeMode.value,
                          onChanged: (m) {
                            kThemeMode.value = m;
                            setState(() {});
                          },
                        ),
                        _RowDivider(),
                        _NavRow(
                          icon: LucideIcons.languages,
                          label: 'Language',
                          trailingText: _language,
                          onTap: _pickLanguage,
                        ),
                        _RowDivider(),
                        _NavRow(
                          icon: LucideIcons.zap,
                          label: 'AI Model',
                          trailingText:
                              widget.controller.model.label,
                          onTap: _pickModel,
                        ),
                      ]),
                      const SizedBox(height: 22),
                      const _SectionLabel('GROWTH'),
                      const SizedBox(height: 8),
                      _CardGroup(children: [
                        _NavRow(
                          icon: LucideIcons.rocket,
                          label: 'Mission Center',
                          trailingText: 'Reward',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const MissionPage(),
                              ),
                            );
                          },
                        ),
                        _RowDivider(),
                        _NavRow(
                          icon: LucideIcons.award,
                          label: 'Donasi V.I.P',
                          trailingText: 'No Ads',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const VipDonationPage(),
                              ),
                            );
                          },
                        ),
                        if (_isAdmin) _RowDivider(),
                        if (_isAdmin)
                          _NavRow(
                            icon: LucideIcons.shieldCheck,
                            label: 'Admin Dashboard',
                            trailingText: 'Review',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AdminDashboardPage(),
                                ),
                              );
                            },
                          ),
                      ]),
                      const SizedBox(height: 16),
                      _DangerRow(
                        icon: LucideIcons.trash2,
                        label: 'Clear Chat History',
                        onTap: _clearHistory,
                      ),
                      const SizedBox(height: 10),
                      // M18.1 — Sign out
                      _DangerRow(
                        icon: LucideIcons.logOut,
                        label: 'Sign out',
                        onTap: _signOut,
                      ),
                      const SizedBox(height: 22),
                      const _SectionLabel('ABOUT'),
                      const SizedBox(height: 8),
                      _CardGroup(children: [
                        _NavRow(
                          icon: LucideIcons.info,
                          label: 'About ${AppConfig.appName}',
                          trailingText: 'v${AppConfig.appVersion}',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AboutPage(),
                              ),
                            );
                          },
                        ),
                        _RowDivider(),
                        _NavRow(
                          icon: LucideIcons.shield,
                          label: 'Privacy Policy',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyPage(),
                            ),
                          ),
                        ),
                        _RowDivider(),
                        _NavRow(
                          icon: LucideIcons.star,
                          label: 'Rate on Play Store',
                          trailing: const Icon(LucideIcons.externalLink,
                              size: 16, color: AppColors.textMuted),
                          onTap: () => _snackSoon(context),
                        ),
                      ]),
                      const SizedBox(height: 24),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/mascot/claude_ai_mascot.png',
                                  errorBuilder: (_, __, ___) => Container(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'KiKai ',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
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
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _snackSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Segera hadir.')),
    );
  }
}

// ── Building blocks ─────────────────────────────────────────────────────


class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _CardGroup extends StatelessWidget {
  final List<Widget> children;
  const _CardGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(children: children),
    );
  }
}

class _RowDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppColors.divider,
      indent: 56,
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailingText;
  final Widget? trailing;
  final VoidCallback onTap;

  const _NavRow({
    required this.icon,
    required this.label,
    this.trailingText,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.iconTile,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (trailingText != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  trailingText!,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            trailing ??
                const Icon(LucideIcons.chevronRight, size: 16,
                    color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _DangerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DangerRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.danger.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.danger.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.dangerTile,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    size: 18, color: AppColors.danger),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(LucideIcons.chevronRight, size: 16,
                  color: AppColors.danger),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;
  const _ThemeRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = value == ThemeMode.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.iconTile,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.palette,
                size: 18, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Theme',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                _SegBtn(
                  label: 'Dark',
                  active: isDark,
                  onTap: () => onChanged(ThemeMode.dark),
                ),
                _SegBtn(
                  label: 'Light',
                  active: !isDark,
                  onTap: () => onChanged(ThemeMode.light),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SegBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: active ? AppColors.avatarGradient : null,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.surface : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
