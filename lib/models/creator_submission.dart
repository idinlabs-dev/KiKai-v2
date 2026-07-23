/// M19 — Creator Mission submission model.
///
/// Doc path: `creator_submissions/{submissionId}`.
///
/// Reward tier (dibaca dari `views` saat approve):
///   >=  300 → `no_ads`
///   >= 1000 → `claude_pro_30d`
///   >= 5000 → `nvidia_premium`
///
/// Status lifecycle: `pending` → (`approved` | `rejected`).
class CreatorSubmission {
  final String id;
  final String uid;
  final String username;
  final String platform;      // 'tiktok' | 'instagram' | 'youtube' | 'facebook'
  final String videoUrl;
  final int views;
  final String status;        // 'pending' | 'approved' | 'rejected'
  final String? reward;       // 'no_ads' | 'claude_pro_30d' | 'nvidia_premium'
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? notes;

  const CreatorSubmission({
    required this.id,
    required this.uid,
    required this.username,
    required this.platform,
    required this.videoUrl,
    required this.views,
    required this.status,
    required this.createdAt,
    this.reward,
    this.reviewedAt,
    this.reviewedBy,
    this.notes,
  });

  factory CreatorSubmission.fromMap(String id, Map<String, dynamic> m) {
    DateTime parseTs(dynamic v) {
      if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
      // Firestore Timestamp — via dynamic to avoid hard import.
      try {
        return (v as dynamic).toDate() as DateTime;
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }

    return CreatorSubmission(
      id: id,
      uid: (m['uid'] ?? '').toString(),
      username: (m['username'] ?? '').toString(),
      platform: (m['platform'] ?? 'tiktok').toString(),
      videoUrl: (m['video_url'] ?? '').toString(),
      views: (m['views'] is num) ? (m['views'] as num).toInt() : 0,
      status: (m['status'] ?? 'pending').toString(),
      reward: m['reward']?.toString(),
      createdAt: parseTs(m['created_at']),
      reviewedAt: m['reviewed_at'] == null ? null : parseTs(m['reviewed_at']),
      reviewedBy: m['reviewed_by']?.toString(),
      notes: m['notes']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'username': username,
        'platform': platform,
        'video_url': videoUrl,
        'views': views,
        'status': status,
        'reward': reward,
        'created_at': createdAt.toIso8601String(),
        'reviewed_at': reviewedAt?.toIso8601String(),
        'reviewed_by': reviewedBy,
        'notes': notes,
      };

  /// Tier reward berdasarkan jumlah views. Null kalau belum memenuhi
  /// tier terendah.
  static String? rewardForViews(int views) {
    if (views >= 5000) return 'nvidia_premium';
    if (views >= 1000) return 'claude_pro_30d';
    if (views >= 300) return 'no_ads';
    return null;
  }

  static String rewardLabel(String? reward) {
    switch (reward) {
      case 'no_ads':
        return 'No Ads Permanen';
      case 'claude_pro_30d':
        return 'KiKai Pro 30 Hari';
      case 'nvidia_premium':
        return 'Nvidia Premium Unlock';
      default:
        return '-';
    }
  }
}
