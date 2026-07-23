/// M21 — Item notifikasi in-app.
///
/// Dua sumber:
/// 1. **Broadcast global** dari admin dashboard
///    (`broadcasts/{id}` di Firestore).
/// 2. **Lokal per-user** hasil aksi in-app
///    (`users/{uid}/notifications/{id}` di Firestore).
///    Contoh: daily check-in sukses, misi disetujui admin, dsb.
///
/// Kedua sumber di-normalize ke class ini lalu di-merge & sort desc oleh
/// [NotificationsService].
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;         // 'broadcast' | 'streak' | 'mission' | 'system'
  final DateTime createdAt;
  final bool isBroadcast;
  final bool read;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    required this.isBroadcast,
    this.read = false,
  });

  factory AppNotification.fromMap(
    String id,
    Map<String, dynamic> m, {
    required bool isBroadcast,
  }) {
    DateTime parseTs(dynamic v) {
      if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) {
        return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
      }
      try {
        return (v as dynamic).toDate() as DateTime;
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }

    return AppNotification(
      id: id,
      title: (m['title'] ?? '').toString(),
      body: (m['body'] ?? '').toString(),
      type: (m['type'] ?? (isBroadcast ? 'broadcast' : 'system')).toString(),
      createdAt: parseTs(m['createdAt'] ?? m['created_at']),
      isBroadcast: isBroadcast,
      read: m['read'] == true,
    );
  }
}
