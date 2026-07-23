import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/creator_submission.dart';
import '../models/user_entitlements.dart';
import 'auth_service.dart';
import 'firebase_service.dart';

/// M19 — Client service untuk Creator Mission.
///
/// - User: [submit], [mySubmissionsStream].
/// - Admin (dipanggil via [AdminService]): [pendingStream], [review].
class CreatorMissionService {
  CreatorMissionService._();
  static final CreatorMissionService instance = CreatorMissionService._();

  static const _kColl = 'creator_submissions';

  FirebaseFirestore? get _db =>
      FirebaseService.instance.isReady ? FirebaseFirestore.instance : null;

  CollectionReference<Map<String, dynamic>>? _col() =>
      _db?.collection(_kColl);

  /// M19.3 — Submit link. Validasi minimum di sisi client; rules Firestore
  /// jadi lapisan kedua.
  ///
  /// Return doc id kalau sukses.
  Future<String> submit({
    required String platform,
    required String videoUrl,
    required String username,
  }) async {
    final col = _col();
    if (col == null) {
      throw StateError('Firebase belum siap.');
    }
    final uid = AuthService.instance.current?.uid ?? '';
    if (uid.isEmpty) {
      throw StateError('Kamu belum sign-in.');
    }
    final url = videoUrl.trim();
    if (url.isEmpty) throw ArgumentError('Link video wajib diisi.');
    if (platform == 'tiktok' && !url.contains('tiktok.com')) {
      throw ArgumentError('Link harus dari TikTok (tiktok.com).');
    }
    if (!(url.startsWith('http://') || url.startsWith('https://'))) {
      throw ArgumentError('Link harus diawali http:// atau https://');
    }

    // M19.6 — duplicate URL check (client-side).
    final dupe = await col
        .where('video_url', isEqualTo: url)
        .limit(1)
        .get();
    if (dupe.docs.isNotEmpty) {
      throw StateError('Video ini sudah pernah diajukan.');
    }

    final ref = await col.add({
      'uid': uid,
      'username': username.trim(),
      'platform': platform,
      'video_url': url,
      'views': 0,
      'status': 'pending',
      'reward': null,
      'created_at': FieldValue.serverTimestamp(),
      'reviewed_at': null,
      'reviewed_by': null,
      'notes': null,
    });
    return ref.id;
  }

  Stream<List<CreatorSubmission>> mySubmissionsStream() {
    final col = _col();
    final uid = AuthService.instance.current?.uid ?? '';
    if (col == null || uid.isEmpty) {
      return const Stream<List<CreatorSubmission>>.empty();
    }
    return col
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => CreatorSubmission.fromMap(d.id, d.data()))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<CreatorSubmission>> pendingStream() {
    final col = _col();
    if (col == null) return const Stream<List<CreatorSubmission>>.empty();
    return col
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => CreatorSubmission.fromMap(d.id, d.data()))
          .toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  /// M19.4 + M19.5 — Admin review. Kalau `approve=true`:
  /// - tetapkan reward tier berdasarkan `views` (via
  ///   [CreatorSubmission.rewardForViews]);
  /// - update `users/{uid}` entitlement flags (no_ads / pro_expired /
  ///   nvidia_unlock);
  /// - mark `creator_reward_claimed=true` untuk mencegah double claim
  ///   (M19.6 anti-abuse).
  ///
  /// Kalau `approve=false`: tandai `rejected` tanpa memberikan reward.
  Future<void> review({
    required CreatorSubmission submission,
    required bool approve,
    required String adminUid,
    int? overrideViews,
    String? notes,
  }) async {
    final col = _col();
    if (col == null) throw StateError('Firebase belum siap.');
    final views = overrideViews ?? submission.views;
    final reward =
        approve ? CreatorSubmission.rewardForViews(views) : null;

    await col.doc(submission.id).update({
      'views': views,
      'status': approve ? 'approved' : 'rejected',
      'reward': reward,
      'reviewed_at': FieldValue.serverTimestamp(),
      'reviewed_by': adminUid,
      'notes': notes,
    });

    if (!approve || reward == null) return;

    // Terapkan entitlement ke user.
    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(submission.uid);
    final patch = <String, dynamic>{
      'creator_reward_claimed': true,
      'creator_last_reward': reward,
      'creator_last_reward_at': FieldValue.serverTimestamp(),
    };
    switch (reward) {
      case 'no_ads':
        patch['no_ads'] = true;
        break;
      case 'claude_pro_30d':
        patch['no_ads'] = true;
        patch['pro_expired'] =
            DateTime.now().add(const Duration(days: 30)).toIso8601String();
        break;
      case 'nvidia_premium':
        patch['no_ads'] = true;
        patch['nvidia_unlock'] = true;
        patch['pro_expired'] =
            DateTime.now().add(const Duration(days: 30)).toIso8601String();
        break;
    }
    await userDoc.set(patch, SetOptions(merge: true));
  }

  /// Fetch entitlements user dari profile doc. Return default kalau
  /// firestore belum ready.
  Future<UserEntitlements> fetchEntitlements(String uid) async {
    final db = _db;
    if (db == null || uid.isEmpty) return const UserEntitlements();
    try {
      final snap = await db.collection('users').doc(uid).get();
      return UserEntitlements.fromMap(snap.data());
    } catch (_) {
      return const UserEntitlements();
    }
  }
}
