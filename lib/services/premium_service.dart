import 'native_bridge.dart';

/// M7 — Premium validator: gabungan streak lokal + native token verifier.
///
/// Token format = `<streakDays>:<hmacHex>` — dihitung server-side (atau
/// oleh `vault_expected_token` native). Kalau attacker paksa
/// `premiumActive=true` di Dart tanpa panggil native, method
/// [isPremiumTrusted] tetap return false.
class PremiumService {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  /// Verifikasi token premium ke native (memek.so → vault.so).
  Future<bool> isPremiumTrusted({
    required String token,
    required int streakDays,
  }) {
    if (token.isEmpty || streakDays <= 0) return Future.value(false);
    return NativeBridge.verifyPremium(token: token, streakDays: streakDays);
  }
}
