import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';
import '../../services/social_auth_service.dart';
import 'verify_screen.dart';
import 'widgets/auth_widgets.dart';

/// M13 — Register screen; M16 — tambah shortcut OAuth Google + Facebook
/// di atas form biar user gak wajib lewat verifikasi email.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _googleLoading = false;
  bool _fbLoading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.isEmpty) {
      setState(() => _error = 'Nama, email, dan password wajib diisi.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.instance.register(
        email: _email.text,
        password: _password.text,
        name: _name.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VerifyScreen(email: _email.text.trim()),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() { _googleLoading = true; _error = null; });
    try {
      final s = await SocialAuthService.instance.signInWithGoogle();
      await FirebaseService.instance.upsertProfile(email: s.email, name: s.name);
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _facebook() async {
    setState(() { _fbLoading = true; _error = null; });
    try {
      final s = await SocialAuthService.instance.signInWithFacebook();
      await FirebaseService.instance.upsertProfile(email: s.email, name: s.name);
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _fbLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final anyLoading = _loading || _googleLoading || _fbLoading;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthHeaderBadge(icon: Icons.person_add_alt_1_rounded),
              const SizedBox(height: 24),
              const AuthTitle(
                title: 'Buat akun',
                subtitle: 'Daftar 1-tap pakai Google / Facebook, atau isi form di bawah.',
              ),
              const SizedBox(height: 24),
              SocialAuthButton(
                label: 'Lanjut dengan Google',
                icon: const GoogleGlyph(),
                loading: _googleLoading,
                onPressed: anyLoading ? () {} : _google,
              ),
              const SizedBox(height: 12),
              SocialAuthButton(
                label: 'Lanjut dengan Facebook',
                icon: const FacebookGlyph(),
                loading: _fbLoading,
                onPressed: anyLoading ? () {} : _facebook,
              ),
              const SizedBox(height: 22),
              const AuthOrDivider(label: 'atau daftar dengan email'),
              const SizedBox(height: 22),
              const AuthLabel('Nama'),
              AuthField(controller: _name, hint: 'Nama lengkap kamu', icon: Icons.person_outline),
              const SizedBox(height: 16),
              const AuthLabel('Email'),
              AuthField(
                controller: _email,
                hint: 'nama@email.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              const AuthLabel('Password'),
              AuthField(
                controller: _password,
                hint: 'Minimal 6 karakter',
                icon: Icons.lock_outline,
                obscure: _obscure,
                trailing: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.textMuted, size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                AuthErrorText(_error!),
              ],
              const SizedBox(height: 20),
              AuthPrimaryButton(
                label: 'Kirim kode verifikasi',
                loading: _loading,
                onPressed: anyLoading ? () {} : _submit,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Sudah punya akun? ',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  GestureDetector(
                    onTap: anyLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Login',
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
