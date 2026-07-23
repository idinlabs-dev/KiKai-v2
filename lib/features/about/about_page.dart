import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';

/// M31 — About page profesional. Menceritakan aplikasi KiKai,
/// developer (Idin Iskandar) + link sosial media & Hugging Face.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _instagram = 'https://instagram.com/idin_iskndr';
  static const _linkedin =
      'https://id.linkedin.com/in/idin-iskandar-163773271';
  static const _github = 'https://github.com/idincodingweb/';
  static const _hfHacking =
      'https://huggingface.co/IDINN/KiKai-For-Hacking-7.6B';
  static const _hfUniversal =
      'https://huggingface.co/IDINN/KiKai-Universal-7B';

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak bisa membuka $url')),
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
        title: Text('About ${AppConfig.appName}'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // ── Developer hero ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Idin Iskandar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Solo Developer • Pencipta aplikasi ini',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ── Tentang aplikasi ───────────────────────────────────
            const _SectionTitle('Tentang KiKai'),
            const SizedBox(height: 8),
            _Card(
              child: const Text(
                'KiKai adalah asisten AI mobile-first yang dirancang '
                'untuk menemani aktivitas harian kamu — mulai dari '
                'coding, riset, menulis, sampai sekadar ngobrol. '
                'Dibangun dengan fokus pada kecepatan, privasi, dan '
                'kualitas jawaban, KiKai menghadirkan model reasoning '
                'kelas flagship yang dulunya hanya bisa diakses lewat '
                'infrastruktur mahal — sekarang ada di genggaman '
                'kamu, gratis dan tanpa batas berlangganan.\n\n'
                'Aplikasi ini dikembangkan sepenuhnya secara mandiri '
                '(solo development) oleh Idin Iskandar, mencakup UI/UX, '
                'backend proxy, sistem autentikasi, misi harian, '
                'monetisasi via AdMob, hingga pelatihan varian model '
                'KiKai yang dipublikasikan open-source di Hugging Face.',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ),
            const SizedBox(height: 22),

            // ── Fitur utama ────────────────────────────────────────
            const _SectionTitle('Fitur Utama'),
            const SizedBox(height: 8),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _Feature(
                    icon: Icons.bolt_rounded,
                    title: 'KiKai Pro',
                    desc:
                        'Model reasoning flagship dengan konteks luas '
                        'dan kemampuan berpikir mendalam.',
                  ),
                  SizedBox(height: 10),
                  _Feature(
                    icon: Icons.history_rounded,
                    title: 'Riwayat & Sesi',
                    desc:
                        'Semua percakapan tersimpan aman di perangkat '
                        'dan bisa dilanjutkan kapan pun.',
                  ),
                  SizedBox(height: 10),
                  _Feature(
                    icon: Icons.rocket_launch_rounded,
                    title: 'Mission Center',
                    desc:
                        'Klaim reward premium lewat Daily Check-In & '
                        'Creator Mission (TikTok).',
                  ),
                  SizedBox(height: 10),
                  _Feature(
                    icon: Icons.shield_moon_rounded,
                    title: 'Privacy First',
                    desc:
                        'Tidak ada API key rahasia di dalam APK — '
                        'komunikasi model dilewatkan proxy terenkripsi.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ── Social media ───────────────────────────────────────
            const _SectionTitle('Terhubung dengan Developer'),
            const SizedBox(height: 8),
            _Card(
              child: Column(
                children: [
                  _LinkRow(
                    icon: Icons.camera_alt_rounded,
                    label: 'Instagram',
                    value: '@idin_iskndr',
                    onTap: () => _open(context, _instagram),
                  ),
                  const _RowDivider(),
                  _LinkRow(
                    icon: Icons.work_rounded,
                    label: 'LinkedIn',
                    value: 'Idin Iskandar',
                    onTap: () => _open(context, _linkedin),
                  ),
                  const _RowDivider(),
                  _LinkRow(
                    icon: Icons.code_rounded,
                    label: 'GitHub',
                    value: '@idincodingweb',
                    onTap: () => _open(context, _github),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ── Open source models ─────────────────────────────────
            const _SectionTitle('Model AI Open Source'),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.only(left: 4, right: 4, bottom: 8),
              child: Text(
                'Varian model KiKai yang saya latih dan publikasikan '
                'secara publik di Hugging Face.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
            _Card(
              child: Column(
                children: [
                  _LinkRow(
                    icon: Icons.security_rounded,
                    label: 'KiKai-For-Hacking-7.6B',
                    value: 'huggingface.co/IDINN',
                    onTap: () => _open(context, _hfHacking),
                  ),
                  const _RowDivider(),
                  _LinkRow(
                    icon: Icons.hub_rounded,
                    label: 'KiKai-Universal-7B',
                    value: 'huggingface.co/IDINN',
                    onTap: () => _open(context, _hfUniversal),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),

            // ── Version footer ─────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Text(
                    '${AppConfig.appName} v${AppConfig.appVersion}'
                    '  •  build ${AppConfig.appBuild}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '© 2026 Idin Iskandar. Dibuat di Indonesia.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Building blocks ──────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: child,
      );
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _Feature({
    required this.icon,
    required this.title,
    required this.desc,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      )),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded,
                size: 16, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) => const Divider(
        height: 1,
        thickness: 1,
        color: AppColors.divider,
      );
}
