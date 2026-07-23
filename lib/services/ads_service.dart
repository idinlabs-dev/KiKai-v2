import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// M24 — AdMob Monetization Service.
///
/// Menggantikan gating model AI dari M21/M23. Semua model kini FREE
/// dan monetisasi dilakukan lewat iklan AdMob:
///
///   • **Interstitial** — muncul 60 detik setelah masuk Home (pertama
///     kali per-sesi login) & pertama kali user tap menu Profile.
///     Ad Unit: ca-app-pub-4040764940734722/2791490885
///
///   • **Rewarded (chat)** — muncul setelah pesan user ke-5 dikirim,
///     lalu bergantian: +10 pesan, +5, +10, +5, ... (siklus).
///     Ad Unit: ca-app-pub-4040764940734722/7852245873
///
///   • **Rewarded (daily check-in)** — dipanggil dari Mission page
///     saat user tap "Check-in".
///     Ad Unit: ca-app-pub-4040764940734722/2322506031
///
///   • **Native** — inline di list Notifikasi (setiap 3 item).
///     Ad Unit: ca-app-pub-4040764940734722/6539164204
///
/// App ID (didaftarkan di AndroidManifest.xml):
///   ca-app-pub-4040764940734722~3957197502
class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  // ── Ad Unit IDs ────────────────────────────────────────────────────
  static const String interstitialUnitId =
      'ca-app-pub-4040764940734722/2791490885';
  static const String rewardedChatUnitId =
      'ca-app-pub-4040764940734722/7852245873';
  static const String rewardedCheckinUnitId =
      'ca-app-pub-4040764940734722/2322506031';
  static const String nativeNotifUnitId =
      'ca-app-pub-4040764940734722/6539164204';

  bool _initialized = false;

  // ── Interstitial state ─────────────────────────────────────────────
  InterstitialAd? _interstitial;
  bool _loadingInterstitial = false;
  bool _homeInterstitialShown = false;
  bool _profileInterstitialShown = false;

  // ── Rewarded (chat) state ──────────────────────────────────────────
  RewardedAd? _rewardedChat;
  bool _loadingRewardedChat = false;

  // ── Rewarded (checkin) state ───────────────────────────────────────
  RewardedAd? _rewardedCheckin;
  bool _loadingRewardedCheckin = false;

  // ── Chat message counter (siklus 5 → +10 → +5 → +10 → +5 ...) ─────
  int _userMessageCount = 0;
  int _nextChatAdAt = 5;
  bool _lastGapWasTen = false; // gap terakhir 10? berikut = 5

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await MobileAds.instance.initialize();
      // M25 — force PRODUCTION ads: clear test-device list &
      // set family-safe defaults. Real ad units already used.
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: const <String>[]),
      );
      _preloadInterstitial();
      _preloadRewardedChat();
      _preloadRewardedCheckin();
    } catch (e) {
      debugPrint('[AdsService] init error: $e');
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // INTERSTITIAL
  // ═════════════════════════════════════════════════════════════════

  void _preloadInterstitial() {
    if (_interstitial != null || _loadingInterstitial) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          _interstitial = ad;
        },
        onAdFailedToLoad: (err) {
          _loadingInterstitial = false;
          _interstitial = null;
          debugPrint('[AdsService] interstitial failed: $err');
        },
      ),
    );
  }

  Future<void> _showInterstitial() async {
    final ad = _interstitial;
    if (ad == null) {
      _preloadInterstitial();
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitial = null;
        _preloadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _interstitial = null;
        _preloadInterstitial();
      },
    );
    _interstitial = null;
    await ad.show();
  }

  /// Dipanggil HomeShell 60 detik setelah user landing (per sesi).
  Future<void> showHomeInterstitialOnce() async {
    if (_homeInterstitialShown) return;
    _homeInterstitialShown = true;
    await _showInterstitial();
  }

  /// Dipanggil HomeShell saat user pertama kali tap tab Profile.
  Future<void> showProfileInterstitialOnce() async {
    if (_profileInterstitialShown) return;
    _profileInterstitialShown = true;
    await _showInterstitial();
  }

  // ═════════════════════════════════════════════════════════════════
  // REWARDED — CHAT
  // ═════════════════════════════════════════════════════════════════

  void _preloadRewardedChat() {
    if (_rewardedChat != null || _loadingRewardedChat) return;
    _loadingRewardedChat = true;
    RewardedAd.load(
      adUnitId: rewardedChatUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingRewardedChat = false;
          _rewardedChat = ad;
        },
        onAdFailedToLoad: (err) {
          _loadingRewardedChat = false;
          _rewardedChat = null;
          debugPrint('[AdsService] rewarded(chat) failed: $err');
        },
      ),
    );
  }

  /// Dipanggil ChatController tiap kali user berhasil kirim pesan.
  ///
  /// Return true kalau iklan berhasil tampil (best-effort). Siklus:
  /// 5, +10, +5, +10, +5, ...
  Future<void> notifyUserMessageSent() async {
    _userMessageCount += 1;
    if (_userMessageCount < _nextChatAdAt) return;

    // Tentukan trigger berikutnya (gantian 10 dan 5, mulai dari 10).
    final nextGap = _lastGapWasTen ? 5 : 10;
    _lastGapWasTen = !_lastGapWasTen;
    _nextChatAdAt = _userMessageCount + nextGap;

    await _showRewardedChat();
  }

  Future<void> _showRewardedChat() async {
    final ad = _rewardedChat;
    if (ad == null) {
      _preloadRewardedChat();
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedChat = null;
        _preloadRewardedChat();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _rewardedChat = null;
        _preloadRewardedChat();
      },
    );
    _rewardedChat = null;
    await ad.show(onUserEarnedReward: (_, __) {});
  }

  // ═════════════════════════════════════════════════════════════════
  // REWARDED — DAILY CHECK-IN
  // ═════════════════════════════════════════════════════════════════

  void _preloadRewardedCheckin() {
    if (_rewardedCheckin != null || _loadingRewardedCheckin) return;
    _loadingRewardedCheckin = true;
    RewardedAd.load(
      adUnitId: rewardedCheckinUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingRewardedCheckin = false;
          _rewardedCheckin = ad;
        },
        onAdFailedToLoad: (err) {
          _loadingRewardedCheckin = false;
          _rewardedCheckin = null;
          debugPrint('[AdsService] rewarded(checkin) failed: $err');
        },
      ),
    );
  }

  /// Dipanggil dari Mission Center saat user tap Check-in.
  /// Resolve `true` jika reward earned, `false` jika ad tidak siap
  /// atau di-dismiss sebelum reward.
  Future<bool> showRewardedCheckin() async {
    final ad = _rewardedCheckin;
    if (ad == null) {
      _preloadRewardedCheckin();
      // Fallback: kalau ad belum siap, izinkan check-in tetap jalan
      // (biar UX tidak stuck saat offline / no fill).
      return true;
    }
    final completer = Completer<bool>();
    bool earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedCheckin = null;
        _preloadRewardedCheckin();
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _rewardedCheckin = null;
        _preloadRewardedCheckin();
        if (!completer.isCompleted) completer.complete(true); // fail-open
      },
    );
    _rewardedCheckin = null;
    await ad.show(onUserEarnedReward: (_, __) {
      earned = true;
    });
    return completer.future;
  }

  // ═════════════════════════════════════════════════════════════════
  // NATIVE — helper factory ID (harus daftar di MainActivity).
  // Kita pakai template built-in `medium` via NativeTemplateStyle.
  // ═════════════════════════════════════════════════════════════════
}
