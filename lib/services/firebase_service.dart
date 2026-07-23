import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/chat_message.dart';
import '../models/chat_thread.dart';
import 'auth_service.dart';

/// M7 — Firebase bootstrap + Firestore helper.
///
/// Struktur koleksi:
///   users/{uid}
///     ├─ profile fields
///     ├─ threads/{threadId}       ← ChatThread
///     │    └─ messages/{msgId}    ← ChatMessage
///     └─ streak/current           ← daily streak doc
///
/// Init: `google-services.json` di `android/app/` cukup untuk auto-config.
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  bool _ready = false;
  bool get isReady => _ready;

  Future<void> init() async {
    if (_ready) return;
    try {
      await Firebase.initializeApp();
      _ready = true;
    } catch (e) {
      // Firebase belum terkonfigurasi (mis. lokal tanpa google-services.json)
      // → app tetap boot, fitur cloud dinonaktifkan.
      _ready = false;
    }
  }

  FirebaseFirestore? get _db => _ready ? FirebaseFirestore.instance : null;

  CollectionReference<Map<String, dynamic>>? _userThreads() {
    final uid = AuthService.instance.current?.uid;
    if (uid == null || uid.isEmpty) return null;
    return _db?.collection('users').doc(uid).collection('threads');
  }

  DocumentReference<Map<String, dynamic>>? _streakDoc() {
    final uid = AuthService.instance.current?.uid;
    if (uid == null || uid.isEmpty) return null;
    return _db?.collection('users').doc(uid).collection('streak').doc('current');
  }

  DocumentReference<Map<String, dynamic>>? _profileDoc() {
    final uid = AuthService.instance.current?.uid;
    if (uid == null || uid.isEmpty) return null;
    return _db?.collection('users').doc(uid);
  }

  // ── Profile ────────────────────────────────────────────────
  /// M20 — Selain email/name, sekarang wajib nulis `createdAt` (sekali,
  /// saat first-create) + `lastActiveAt` (setiap panggilan).
  /// Ini fix root cause dashboard admin (M20) tidak melihat user baru:
  /// query pakai `orderBy("createdAt","desc")` sehingga doc tanpa field
  /// ini otomatis di-skip.
  Future<void> upsertProfile({required String email, required String name}) async {
    final doc = _profileDoc();
    if (doc == null) return;
    final snap = await doc.get();
    final data = <String, dynamic>{
      'email': email,
      'name': name,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
    };
    if (!snap.exists || snap.data()?['createdAt'] == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await doc.set(data, SetOptions(merge: true));
  }

  /// M20 — Heartbeat ringan buat dashboard "online users" (window 5 menit).
  /// Panggil dari HomeShell / lifecycle observer tiap ~2 menit saat foreground.
  Future<void> touchLastActive() async {
    final doc = _profileDoc();
    if (doc == null) return;
    await doc.set({
      'lastActiveAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── Chat history ───────────────────────────────────────────
  Future<void> saveThread(ChatThread t) async {
    final col = _userThreads();
    if (col == null) return;
    await col.doc(t.id).set(t.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteThread(String threadId) async {
    final col = _userThreads();
    if (col == null) return;
    // Hapus messages sub-collection dulu (batch)
    final msgs = await col.doc(threadId).collection('messages').get();
    final batch = _db!.batch();
    for (final d in msgs.docs) {
      batch.delete(d.reference);
    }
    batch.delete(col.doc(threadId));
    await batch.commit();
  }

  Future<void> saveMessage(String threadId, ChatMessage m) async {
    final col = _userThreads();
    if (col == null) return;
    await col.doc(threadId).collection('messages').doc(m.id).set(m.toMap());
  }

  // ── Streak ─────────────────────────────────────────────────
  Future<void> upsertStreak({
    required int count,
    required DateTime lastCheckIn,
    required bool premiumActive,
  }) async {
    final doc = _streakDoc();
    if (doc == null) return;
    await doc.set({
      'count': count,
      'lastCheckInIso': lastCheckIn.toIso8601String(),
      'premiumActive': premiumActive,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> fetchStreak() async {
    final doc = _streakDoc();
    if (doc == null) return null;
    final snap = await doc.get();
    return snap.data();
  }

  // ── M18.2 — Single-device session ──────────────────────────
  //
  // Doc path: users/{uid}/session/current
  //   { deviceId, platform, updatedAt }
  //
  // Semua device yang punya session lokal untuk uid yang sama observe
  // doc ini via [sessionSnapshots]. Ketika device lain claim uid → doc
  // ke-overwrite, device lama menerima snapshot dgn deviceId ≠ miliknya
  // → force logout dari [DeviceSessionService].
  DocumentReference<Map<String, dynamic>>? _sessionDoc(String uid) {
    if (uid.isEmpty) return null;
    return _db?.collection('users').doc(uid).collection('session').doc('current');
  }

  Future<bool> claimDevice({
    required String uid,
    required String deviceId,
    required String platform,
  }) async {
    final doc = _sessionDoc(uid);
    if (doc == null) return false;
    try {
      await doc.set({
        'deviceId': deviceId,
        'platform': platform,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>>? sessionSnapshots(String uid) {
    final doc = _sessionDoc(uid);
    if (doc == null) return null;
    return doc.snapshots();
  }

  /// Hapus doc kalau (dan hanya kalau) device ini yang masih tercatat
  /// sebagai owner aktif. Kalau device lain sudah override, biarin —
  /// device itu berhak tetap sign-in.
  Future<void> releaseDeviceIfOwned({
    required String uid,
    required String deviceId,
  }) async {
    final doc = _sessionDoc(uid);
    if (doc == null) return;
    try {
      final snap = await doc.get();
      final data = snap.data();
      if (data == null) return;
      if ((data['deviceId'] ?? '').toString() == deviceId) {
        await doc.delete();
      }
    } catch (_) {}
  }
}

