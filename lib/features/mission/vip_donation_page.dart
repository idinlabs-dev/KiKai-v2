import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';

/// Halaman Donasi V.I.P — jalur alternatif dapetin No Ads tanpa harus
/// bikin konten TikTok. User isi form → kirim via Email atau Telegram
/// dengan lampiran bukti pembayaran.
///
/// Tier:
/// - Rp 20.000  → No Ads 1 bulan
/// - Rp 50.000  → No Ads Lifetime (terbatas)
class VipDonationPage extends StatefulWidget {
  const VipDonationPage({super.key});

  @override
  State<VipDonationPage> createState() => _VipDonationPageState();
}

class _VipDonationPageState extends State<VipDonationPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _amount = TextEditingController();
  final _phone = TextEditingController();

  static const String _targetEmail = 'idiniskandar.tech@gmail.com';
  static const String _telegramUser = 'kikaiadmin';

  @override
  void initState() {
    super.initState();
    // Prefill email dari akun kalau ada.
    final user = AuthService.instance.current;
    if (user != null && user.email.isNotEmpty) _email.text = user.email;
  }

  @override
  void dispose() {
    _email.dispose();
    _amount.dispose();
    _phone.dispose();
    super.dispose();
  }

  String _buildMessage() {
    final email = _email.text.trim();
    final amount = _amount.text.trim();
    final phone = _phone.text.trim();
    return 'Halo Admin KiKai,\n\n'
        'Saya ingin donasi V.I.P untuk akses No Ads.\n\n'
        '• Email akun aplikasi : $email\n'
        '• Total donasi        : Rp $amount\n'
        '• No. HP (opsional)   : ${phone.isEmpty ? '-' : phone}\n\n'
        'Bukti pembayaran saya lampirkan di pesan ini.\n\n'
        'Terima kasih.';
  }

  Future<void> _sendEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final subject = Uri.encodeComponent('Donasi V.I.P KiKai — No Ads');
    final body = Uri.encodeComponent(_buildMessage());
    final uri = Uri.parse('mailto:$_targetEmail?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _snack('Tidak bisa membuka aplikasi email.');
    }
  }

  Future<void> _sendTelegram() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final text = Uri.encodeComponent(_buildMessage());
    // t.me deep-link dengan text (Telegram akan buka chat + prefill).
    final uri = Uri.parse('https://t.me/$_telegramUser?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _snack('Tidak bisa membuka Telegram.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Donasi V.I.P'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _Hero(),
              const SizedBox(height: 16),
              const _TierCard(
                title: 'Rp 20.000',
                subtitle: 'No Ads · 1 Bulan',
                icon: Icons.block_rounded,
                color: AppColors.success,
              ),
              const _TierCard(
                title: 'Rp 50.000',
                subtitle: 'No Ads · Lifetime (Terbatas)',
                icon: Icons.workspace_premium_rounded,
                color: AppColors.warning,
              ),
              const SizedBox(height: 18),
              const Text(
                'Data Donasi',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              _label('Email akun aplikasi'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _dec('email@contoh.com'),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'Email wajib diisi';
                  if (!s.contains('@') || !s.contains('.')) {
                    return 'Format email tidak valid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _label('Total donasi (Rp)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amount,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _dec('20000 / 50000'),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'Total donasi wajib diisi';
                  final n = int.tryParse(s.replaceAll('.', ''));
                  if (n == null || n < 1000) return 'Nominal tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _label('No. HP (opsional)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _dec('08xx-xxxx-xxxx'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.email_rounded),
                  label: const Text('Kirim via Email'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _sendEmail,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Kirim via Telegram'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _sendTelegram,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Text(
                  'Catatan: jangan lupa lampirkan bukti pembayaran (screenshot '
                  'transfer) di pesan email / Telegram sebelum dikirim. '
                  'Admin akan aktifkan No Ads di akun kamu setelah bukti '
                  'diverifikasi.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String s) => Text(
        s,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );

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

class _Hero extends StatelessWidget {
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
            Icon(Icons.workspace_premium_rounded,
                color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text('Jalur V.I.P',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                )),
          ]),
          SizedBox(height: 8),
          Text(
            'Selain bikin konten 500 views, kamu bisa unlock No Ads lewat '
            'donasi. Pilih nominal, isi form, kirim ke admin lewat Email '
            'atau Telegram beserta bukti transfer.',
            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _TierCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

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
              Text(title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 2),
              Text(subtitle,
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
  }
}
