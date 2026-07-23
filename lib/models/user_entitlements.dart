/// M19 — Entitlements yang bisa didapat lewat Creator Mission.
///
/// Semua field disimpan di doc `users/{uid}` (root profile). Sengaja
/// flat supaya sekali `.get()` cukup untuk gate feature seperti
/// AdMob & premium model selector.
class UserEntitlements {
  final bool noAds;
  final DateTime? proExpired;
  final bool nvidiaUnlock;
  final bool creatorRewardClaimed;

  const UserEntitlements({
    this.noAds = false,
    this.proExpired,
    this.nvidiaUnlock = false,
    this.creatorRewardClaimed = false,
  });

  bool get proActive =>
      proExpired != null && proExpired!.isAfter(DateTime.now());

  factory UserEntitlements.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const UserEntitlements();
    DateTime? parseTs(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v);
      try {
        return (v as dynamic).toDate() as DateTime;
      } catch (_) {
        return null;
      }
    }

    return UserEntitlements(
      noAds: m['no_ads'] == true,
      proExpired: parseTs(m['pro_expired']),
      nvidiaUnlock: m['nvidia_unlock'] == true,
      creatorRewardClaimed: m['creator_reward_claimed'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'no_ads': noAds,
        'pro_expired': proExpired?.toIso8601String(),
        'nvidia_unlock': nvidiaUnlock,
        'creator_reward_claimed': creatorRewardClaimed,
      };
}
