import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/streak_state.dart';

/// Service pengelola **Daily Login Streak Premium** (M5).
///
/// **M21 — Perubahan aturan:**
/// - Check-in **tidak lagi otomatis** saat aplikasi dibuka.
/// - User harus **klik tombol "Check-In Hari Ini"** di Mission Center.
/// - Nanti (setelah AdMob aktif) klik itu akan memicu **Rewarded Video Ad**;
///   check-in baru dianggap sah setelah callback `onRewarded`.
/// - Sementara AdMob belum aktif, ada `simulateRewardAd()` yang dipanggil
///   dari UI sebagai placeholder (delay pendek + selalu sukses) supaya
///   flow tombol → check-in tetap ter-test end-to-end.
///
/// Aturan streak tetap:
/// - Hari pertama → streak = 1.
/// - Buka hari H+1 → streak += 1 (cap 7).
/// - Skip ≥ 1 hari (gap ≥ 2 hari lokal) → streak reset ke 1,
///   premium (Balanced model) dicabut.
class StreakService extends ChangeNotifier {
  StreakService._();
  static final StreakService instance = StreakService._();

  static const _kCountKey = 'streak_count';
  static const _kLastDateKey = 'streak_last_date'; // ISO yyyy-MM-dd

  StreakState _state = const StreakState.empty();
  bool _loaded = false;

  StreakState get state => _state;
  bool get isLoaded => _loaded;
  bool get premiumActive => _state.premiumActive;

  /// M21 — Cek apakah user SUDAH check-in hari ini (kalender lokal).
  /// Dipakai UI Mission Center untuk enable/disable tombol.
  bool get hasCheckedInToday {
    final last = _state.lastCheckInDate;
    if (last == null) return false;
    final today = _dateOnly(DateTime.now());
    return _dateOnly(last) == today;
  }

  /// Panggil sekali di startup untuk memuat state tanpa efek samping.
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_kCountKey) ?? 0;
    final lastStr = prefs.getString(_kLastDateKey);
    _state = StreakState(
      count: count,
      lastCheckInDate: lastStr == null ? null : DateTime.tryParse(lastStr),
    );
    _loaded = true;
    notifyListeners();
  }

  Future<void> resetForDebug() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCountKey);
    await prefs.remove(_kLastDateKey);
    _state = const StreakState.empty();
    notifyListeners();
  }

  /// M21 — Placeholder Rewarded Video Ad.
  ///
  /// Setelah AdMob aktif, ganti isi method ini dengan
  /// `RewardedAd.load(...) → ad.show(onUserEarnedReward)` dan return
  /// `true` hanya kalau callback earned dipanggil.
  ///
  /// Return `true` = user memenuhi syarat check-in.
  Future<bool> simulateRewardAd() async {
    // Delay sedikit biar UX terasa seperti nunggu ad load/close.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return true;
  }

  /// Check-in harian. **Butuh user aksi (klik tombol).**
  /// Idempotent dalam 1 hari kalender.
  Future<StreakCheckInResult> checkIn({DateTime? now}) async {
    await load();
    final today = _dateOnly(now ?? DateTime.now());
    final last = _state.lastCheckInDate == null
        ? null
        : _dateOnly(_state.lastCheckInDate!);

    StreakCheckInResult result;
    int newCount;

    if (last == null) {
      newCount = 1;
      result = StreakCheckInResult.firstDay;
    } else {
      final diffDays = today.difference(last).inDays;
      if (diffDays == 0) {
        return StreakCheckInResult.alreadyToday;
      } else if (diffDays == 1) {
        if (_state.count >= StreakState.maxDays) {
          newCount = StreakState.maxDays;
          result = StreakCheckInResult.premiumMaintained;
        } else {
          newCount = _state.count + 1;
          result = newCount >= StreakState.maxDays
              ? StreakCheckInResult.reachedPremium
              : StreakCheckInResult.incremented;
          if (newCount > StreakState.maxDays) newCount = StreakState.maxDays;
        }
      } else {
        newCount = 1;
        result = StreakCheckInResult.broken;
      }
    }

    _state = StreakState(count: newCount, lastCheckInDate: today);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCountKey, newCount);
    await prefs.setString(_kLastDateKey, _isoDate(today));
    notifyListeners();
    return result;
  }

  // ── Helpers ─────────────────────────────────────────────────────────
  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
  String _isoDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  /// M21 — ID stabil untuk notif "daily streak" per hari, biar tidak dobel.
  String todayNotifId() {
    final t = _dateOnly(DateTime.now());
    return 'streak-${_isoDate(t)}';
  }
}
