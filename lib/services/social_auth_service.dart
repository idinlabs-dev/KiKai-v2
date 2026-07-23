import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_service.dart';

/// M16 — Sign-in via Firebase Authentication (Google + Facebook).
///
/// **M21 — Purge**: GAS mirror (`_gasUpsert`, `_gasEndpoint`,
/// `http` import) dihapus. Sinkronisasi user profile sekarang murni
/// via `FirebaseService.upsertProfile()` yang dipanggil di LoginScreen.
///
/// Alur:
///   1. User tap "Continue with Google" / "Continue with Facebook".
///   2. Native SDK ambil OAuth token → tukar jadi Firebase credential.
///   3. Sign in ke Firebase Auth → dapet [User] (uid, email, displayName).
///   4. Persist [AuthSession] via [AuthService] → app langsung sign-in.
class SocialAuthService {
  SocialAuthService._();
  static final SocialAuthService instance = SocialAuthService._();

  final GoogleSignIn _google = GoogleSignIn(scopes: const ['email', 'profile']);

  Future<AuthSession> signInWithGoogle() async {
    final GoogleSignInAccount? gAcc = await _google.signIn();
    if (gAcc == null) {
      throw const SocialAuthException('Login Google dibatalin.');
    }
    final GoogleSignInAuthentication gAuth = await gAcc.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );
    final userCred =
        await FirebaseAuth.instance.signInWithCredential(credential);
    final u = userCred.user;
    if (u == null) throw const SocialAuthException('Firebase user null.');
    return _finalize(
      uid: u.uid,
      email: u.email ?? gAcc.email,
      name: u.displayName ?? gAcc.displayName ?? 'User',
    );
  }

  Future<AuthSession> signInWithFacebook() async {
    final LoginResult res = await FacebookAuth.instance.login(
      permissions: const ['email', 'public_profile'],
    );
    if (res.status == LoginStatus.cancelled) {
      throw const SocialAuthException('Login Facebook dibatalin.');
    }
    if (res.status != LoginStatus.success || res.accessToken == null) {
      throw SocialAuthException(
          'Login Facebook gagal: ${res.message ?? res.status.name}');
    }
    final token = res.accessToken!.tokenString;
    final credential = FacebookAuthProvider.credential(token);
    final userCred =
        await FirebaseAuth.instance.signInWithCredential(credential);
    final u = userCred.user;
    if (u == null) throw const SocialAuthException('Firebase user null.');
    final email = u.email ?? '${u.uid}@facebook.local';
    return _finalize(
      uid: u.uid,
      email: email,
      name: u.displayName ?? 'User',
    );
  }

  Future<void> signOut() async {
    try { await _google.signOut(); } catch (_) {}
    try { await FacebookAuth.instance.logOut(); } catch (_) {}
    try { await FirebaseAuth.instance.signOut(); } catch (_) {}
  }

  Future<AuthSession> _finalize({
    required String uid,
    required String email,
    required String name,
  }) async {
    final session = AuthSession(uid: uid, email: email, name: name);
    await AuthService.instance.acceptExternalSession(session);
    return session;
  }
}

class SocialAuthException implements Exception {
  final String message;
  const SocialAuthException(this.message);
  @override
  String toString() => message;
}
