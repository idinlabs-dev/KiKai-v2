import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/device_session_service.dart';
import '../../services/firebase_service.dart';
import 'widgets/auth_widgets.dart';

/// M13 — Verify screen redesigned dengan 6 kotak OTP terpisah,
/// mengikuti pola "OTP boxes" pada referensi design.
class VerifyScreen extends StatefulWidget {
  final String email;
  const VerifyScreen({super.key, required this.email});
  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _info;

  Future<void> _verify() async {
    if (_code.text.length < 6) {
      setState(() => _error = 'Masukin 6 digit kode dulu.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final s = await AuthService.instance.verify(
        email: widget.email,
        code: _code.text,
      );
      await FirebaseService.instance.upsertProfile(email: s.email, name: s.name);
      // M18.2 — claim device sekali session valid.
      await DeviceSessionService.instance.claim(s.uid);
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() { _loading = true; _error = null; _info = null; });
    try {
      await AuthService.instance.resendCode(widget.email);
      if (mounted) setState(() => _info = 'Kode baru sudah dikirim ke email kamu.');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthHeaderBadge(icon: Icons.mark_email_read_outlined),
              const SizedBox(height: 24),
              const AuthTitle(
                title: 'Verifikasi email',
                subtitle: 'Kami baru saja ngirim kode 6 digit ke:',
              ),
              const SizedBox(height: 6),
              Text(widget.email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                child: OtpBoxes(controller: _code, onCompleted: _verify),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                AuthErrorText(_error!),
              ],
              if (_info != null) ...[
                const SizedBox(height: 16),
                AuthInfoText(_info!),
              ],
              const SizedBox(height: 28),
              AuthPrimaryButton(label: 'Verifikasi', loading: _loading, onPressed: _verify),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Gak dapet kode? ',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  GestureDetector(
                    onTap: _loading ? null : _resend,
                    child: const Text('Kirim ulang',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
