import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// M7 — AuthService: **session persistence** untuk user yang sign-in via
/// Firebase OAuth (Google / Facebook).
///
/// **M21 — Purge**: seluruh method GAS email/password
/// (`register`, `login`, `verify`, `resendCode`, `_hashPassword`, `_post`,
/// `AuthException`) dihapus. `SocialAuthService` sekarang panggil
/// [acceptExternalSession] setelah Firebase user siap.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _kSessionKey = 'auth_session_v1'; // {uid,email,name}

  AuthSession? _current;
  AuthSession? get current => _current;
  bool get isSignedIn => _current != null;

  Future<void> load() async {
    if (_current != null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSessionKey);
    if (raw == null) return;
    try {
      _current = AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await prefs.remove(_kSessionKey);
    }
  }

  Future<void> signOut() async {
    _current = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionKey);
  }

  /// Dipakai [SocialAuthService] setelah Firebase OAuth sukses:
  /// simpan session yang dibuat dari Firebase user.
  Future<void> acceptExternalSession(AuthSession s) => _persist(s);

  Future<void> _persist(AuthSession s) async {
    _current = s;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSessionKey, jsonEncode(s.toJson()));
  }
}

class AuthSession {
  final String uid;
  final String email;
  final String name;
  const AuthSession({
    required this.uid,
    required this.email,
    required this.name,
  });

  Map<String, dynamic> toJson() => {'uid': uid, 'email': email, 'name': name};
  factory AuthSession.fromJson(Map<String, dynamic> j) => AuthSession(
        uid: (j['uid'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
      );
}
