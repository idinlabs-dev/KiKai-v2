/// State harian daily login streak (M5).
///
/// - [count] jumlah hari berturut-turut yang tercatat (0..[maxDays]).
/// - [lastCheckInDate] tanggal check-in terakhir (di-normalize ke midnight
///   lokal). Null = belum pernah check-in.
/// - [premiumActive] = derivasi dari [count] >= [maxDays]. Reward berlaku
///   selama streak dipertahankan; kalau [count] direset karena user skip
///   >=1 hari, otomatis dicabut.
class StreakState {
  final int count;
  final DateTime? lastCheckInDate;

  static const int maxDays = 7;

  const StreakState({
    required this.count,
    required this.lastCheckInDate,
  });

  const StreakState.empty()
      : count = 0,
        lastCheckInDate = null;

  bool get premiumActive => count >= maxDays;

  StreakState copyWith({int? count, DateTime? lastCheckInDate}) {
    return StreakState(
      count: count ?? this.count,
      lastCheckInDate: lastCheckInDate ?? this.lastCheckInDate,
    );
  }
}

/// Hasil operasi check-in harian — dipakai UI untuk pilih dialog/snackbar.
enum StreakCheckInResult {
  /// Sudah check-in hari ini sebelumnya. Tidak ada perubahan.
  alreadyToday,

  /// Hari pertama (sebelumnya belum ada state).
  firstDay,

  /// Streak lanjut (count bertambah) tapi belum mencapai premium.
  incremented,

  /// Streak lanjut & MENCAPAI hari ke-7 → premium aktif hari ini.
  reachedPremium,

  /// Sudah premium & tetap dipertahankan (count tetap di 7).
  premiumMaintained,

  /// Streak terputus (gap ≥ 2 hari) → count reset ke 1, premium dicabut.
  broken,
}
