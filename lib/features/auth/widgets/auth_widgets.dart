import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// M21 — Auth UI kit (purged).
///
/// Karena aplikasi 100% OAuth (Google + Facebook), widget khusus form
/// email/password + OTP tidak dipakai lagi dan sudah dihapus:
///   `AuthLabel`, `AuthField`, `AuthPrimaryButton`, `OtpBoxes`,
///   `AuthOrDivider`, `AuthInfoText`.
///
/// Yang tersisa (dipakai [LoginScreen]):
///   [AuthHeaderBadge], [AuthTitle], [SocialAuthButton],
///   [GoogleGlyph], [FacebookGlyph], [AuthErrorText].

class AuthHeaderBadge extends StatelessWidget {
  final IconData icon;
  const AuthHeaderBadge({super.key, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 88, height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.brandGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.35),
              blurRadius: 24, spreadRadius: 2, offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 40),
      ),
    );
  }
}

class AuthTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const AuthTitle({super.key, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5)),
        const SizedBox(height: 8),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
      ],
    );
  }
}

class SocialAuthButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final bool loading;
  final VoidCallback onPressed;
  const SocialAuthButton({
    super.key,
    required this.label,
    required this.icon,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceElevated,
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 22, height: 22, child: icon),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class GoogleGlyph extends StatelessWidget {
  const GoogleGlyph({super.key});
  @override
  Widget build(BuildContext context) {
    // Simple "G" pill — tidak pakai asset PNG supaya bundling ringan.
    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
    );
  }
}

class FacebookGlyph extends StatelessWidget {
  const FacebookGlyph({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF1877F2),
      ),
      child: const Text(
        'f',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
    );
  }
}

class AuthErrorText extends StatelessWidget {
  final String message;
  const AuthErrorText(this.message, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
