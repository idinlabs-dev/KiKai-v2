import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/device_session_service.dart';
import '../../services/firebase_service.dart';
import '../../services/social_auth_service.dart';
import '../home/home_shell.dart';
import 'widgets/auth_widgets.dart';

/// M7 — Auth gate: kalau session ada → child. Kalau tidak → LoginScreen.
///
/// M18.2 — Selain gating auth, gate juga (a) klaim device ke Firestore
/// `users/{uid}/session/current` sekali session tersedia, (b) dengerin
/// [DeviceSessionService.kicked] — kalau device lain klaim uid yg sama,
/// force sign-out + dialog di device ini.
///
/// M20 — Form email/password + verifikasi OTP dihapus. Hanya Google &
/// Facebook OAuth (native Firebase Authentication).
class AuthGate extends StatefulWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _showingKickDialog = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    DeviceSessionService.instance.kicked.addListener(_onKicked);
  }

  @override
  void dispose() {
    DeviceSessionService.instance.kicked.removeListener(_onKicked);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await AuthService.instance.load();
    // M18.2 — session restored → langsung claim device (idempotent).
    if (AuthService.instance.isSignedIn) {
      // ignore: unawaited_futures
      DeviceSessionService.instance.claimCurrent();
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _onKicked() async {
    if (!mounted) return;
    if (!DeviceSessionService.instance.kicked.value) return;
    if (_showingKickDialog) return;
    _showingKickDialog = true;
    await AuthService.instance.signOut();
    await SocialAuthService.instance.signOut();
    await DeviceSessionService.instance.stop();
    if (!mounted) {
      _showingKickDialog = false;
      return;
    }
    setState(() {}); // rebuild → LoginScreen
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Sesi berakhir'),
        content: const Text(
          'Akun ini baru saja login di perangkat lain. '
          'Untuk keamanan, sesi di perangkat ini otomatis di-logout.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    _showingKickDialog = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!AuthService.instance.isSignedIn) return const LoginScreen();
    return widget.child;
  }
}

/// M20 — LoginScreen: OAuth-only (Google + Facebook).
///
/// Semua form email/password + navigasi ke RegisterScreen / VerifyScreen
/// (M7/M13/M16) dihapus. Owner mandate: aplikasi murni Firebase Auth.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _googleLoading = false;
  bool _fbLoading = false;
  String? _error;

  bool get _anyLoading => _googleLoading || _fbLoading;

  Future<void> _google() async {
    if (_anyLoading) return;
    setState(() { _googleLoading = true; _error = null; });
    try {
      final s = await SocialAuthService.instance.signInWithGoogle();
      await FirebaseService.instance.upsertProfile(email: s.email, name: s.name);
      await DeviceSessionService.instance.claim(s.uid);
      _goHome();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _facebook() async {
    if (_anyLoading) return;
    setState(() { _fbLoading = true; _error = null; });
    try {
      final s = await SocialAuthService.instance.signInWithFacebook();
      await FirebaseService.instance.upsertProfile(email: s.email, name: s.name);
      await DeviceSessionService.instance.claim(s.uid);
      _goHome();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _fbLoading = false);
    }
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const AuthHeaderBadge(icon: Icons.bolt_rounded),
              const SizedBox(height: 28),
              const AuthTitle(
                title: 'Selamat datang',
                subtitle:
                    'Masuk 1-tap pakai akun Google atau Facebook untuk lanjut ngobrol sama KiKai.',
              ),
              const SizedBox(height: 40),
              SocialAuthButton(
                label: 'Lanjut dengan Google',
                icon: const GoogleGlyph(),
                loading: _googleLoading,
                onPressed: _google,
              ),
              const SizedBox(height: 14),
              SocialAuthButton(
                label: 'Lanjut dengan Facebook',
                icon: const FacebookGlyph(),
                loading: _fbLoading,
                onPressed: _facebook,
              ),
              if (_error != null) ...[
                const SizedBox(height: 20),
                AuthErrorText(_error!),
              ],
              const SizedBox(height: 32),
              const Text(
                'Dengan melanjutkan, kamu setuju dengan Ketentuan Layanan '
                'dan Kebijakan Privasi KiKai.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
