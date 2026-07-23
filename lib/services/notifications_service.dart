import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';
import 'auth_service.dart';
import 'firebase_service.dart';

/// M21 — Notifications hub.
///
/// - Broadcast admin: `broadcasts/{id}`  { title, body, created_at, created_by, audience }
/// - Lokal per-user : `users/{uid}/notifications/{id}`
///                    { title, body, type, createdAt, read }
///
/// UI (NotificationsScreen) dengarkan [combinedStream]; item digabung
/// lalu di-sort desc by createdAt.
///
/// **Fallback safety**: kalau `rxdart` tidak tersedia (harusnya sudah
/// masuk pubspec), atau salah satu stream fail, service tetap balikin
/// stream kosong biar UI tidak crash.
class NotificationsService {
  NotificationsService._();
  static final NotificationsService instance = NotificationsService._();

  FirebaseFirestore? get _db =>
      FirebaseService.instance.isReady ? FirebaseFirestore.instance : null;

  CollectionReference<Map<String, dynamic>>? _broadcasts() =>
      _db?.collection('broadcasts');

  CollectionReference<Map<String, dynamic>>? _userNotif() {
    final uid = AuthService.instance.current?.uid;
    if (uid == null || uid.isEmpty) return null;
    return _db?.collection('users').doc(uid).collection('notifications');
  }

  /// Stream gabungan (broadcast + personal), sorted desc by createdAt.
  Stream<List<AppNotification>> combinedStream() {
    final bCol = _broadcasts();
    final uCol = _userNotif();

    Stream<List<AppNotification>> bStream = bCol == null
        ? Stream.value(const <AppNotification>[])
        : bCol
            // Dashboard admin (appchatadmin) menulis field `created_at`
            // (snake_case). Sebelumnya query ini pakai `createdAt` →
            // Firestore auto-exclude semua dokumen tanpa field itu →
            // broadcast admin tidak pernah muncul. Fix: order by
            // `created_at`. AppNotification.fromMap sudah tolerant
            // dua-duanya di level parsing.
            .orderBy('created_at', descending: true)
            .limit(50)
            .snapshots()
            .map((s) => s.docs
                .map((d) => AppNotification.fromMap(
                      d.id,
                      d.data(),
                      isBroadcast: true,
                    ))
                .toList())
            .handleError((_) => const <AppNotification>[]);

    Stream<List<AppNotification>> uStream = uCol == null
        ? Stream.value(const <AppNotification>[])
        : uCol
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots()
            .map((s) => s.docs
                .map((d) => AppNotification.fromMap(
                      d.id,
                      d.data(),
                      isBroadcast: false,
                    ))
                .toList())
            .handleError((_) => const <AppNotification>[]);

    return _combineLatest2(bStream, uStream, (b, u) {
      final merged = <AppNotification>[...b, ...u];
      merged.sort((x, y) => y.createdAt.compareTo(x.createdAt));
      return merged;
    });
  }

  /// Minimal combineLatest2 tanpa rxdart. Emit setiap kali salah satu
  /// stream update, dgn latest value dari yang lain (atau list kosong
  /// kalau belum pernah emit).
  static Stream<R> _combineLatest2<A, B, R>(
    Stream<A> a,
    Stream<B> b,
    R Function(A, B) combine,
  ) {
    late StreamController<R> ctrl;
    A? lastA;
    B? lastB;
    bool hasA = false, hasB = false;
    StreamSubscription<A>? subA;
    StreamSubscription<B>? subB;

    void emit() {
      if (!hasA || !hasB) return;
      try {
        ctrl.add(combine(lastA as A, lastB as B));
      } catch (e, s) {
        ctrl.addError(e, s);
      }
    }

    ctrl = StreamController<R>(
      onListen: () {
        subA = a.listen((v) {
          lastA = v; hasA = true; emit();
        }, onError: ctrl.addError);
        subB = b.listen((v) {
          lastB = v; hasB = true; emit();
        }, onError: ctrl.addError);
      },
      onCancel: () async {
        await subA?.cancel();
        await subB?.cancel();
      },
    );
    return ctrl.stream;
  }

  /// M21 — Push notifikasi lokal (mis. daily check-in sukses).
  /// Idempotent: caller boleh assign `id` sendiri (mis.
  /// `streak-2026-07-03`) supaya tidak dobel per hari.
  Future<void> pushLocal({
    required String title,
    required String body,
    String type = 'system',
    String? id,
  }) async {
    final col = _userNotif();
    if (col == null) return;
    final data = {
      'title': title,
      'body': body,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    };
    try {
      if (id != null) {
        await col.doc(id).set(data);
      } else {
        await col.add(data);
      }
    } catch (_) {
      // silent — notifikasi lokal bukan critical path.
    }
  }

  Future<void> markAllRead() async {
    final col = _userNotif();
    if (col == null) return;
    try {
      final snap = await col.where('read', isEqualTo: false).limit(50).get();
      final batch = _db!.batch();
      for (final d in snap.docs) {
        batch.update(d.reference, {'read': true});
      }
      await batch.commit();
    } catch (_) {}
  }
}
