import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import 'firebase_service.dart';

/// M19 / M20 — Admin gate.
///
/// Admin ditandai lewat field boolean `is_admin: true` di doc
/// `users/{uid}`. Bootstrap awal: set manual di Firestore console.
///
/// Kenapa tidak custom claim JWT? Auth backend utama masih GAS —
/// Firebase Auth cuma untuk OAuth (M16). Menyimpan role di Firestore
/// tetap aman karena Firestore Rules yang menegakkan (rules snippet
/// tersedia di `backend/firestore.rules`).
class AdminService {
  AdminService._();
  static final AdminService instance = AdminService._();

  bool _cached = false;
  bool _isAdmin = false;

  bool get isAdminCached => _isAdmin;

  Future<bool> refresh() async {
    _cached = false;
    return isAdmin();
  }

  Future<bool> isAdmin() async {
    if (_cached) return _isAdmin;
    if (!FirebaseService.instance.isReady) return false;
    final uid = AuthService.instance.current?.uid ?? '';
    if (uid.isEmpty) return false;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      _isAdmin = snap.data()?['is_admin'] == true;
      _cached = true;
    } catch (_) {
      _isAdmin = false;
    }
    return _isAdmin;
  }

  void clear() {
    _cached = false;
    _isAdmin = false;
  }
}
