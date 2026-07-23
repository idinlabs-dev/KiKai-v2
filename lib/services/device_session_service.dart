import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'auth_service.dart';
import 'firebase_service.dart';

/// M18.2 — Enforce **1 akun = 1 device**.
///
/// Alur:
/// 1. Generate `deviceId` sekali per install (UUID v4 persist di
///    `SharedPreferences`). Uninstall / Clear Data → dianggap device baru.
/// 2. Saat user sign-in (email/password, OAuth, atau restore session)
///    → `claim(uid)` write ke Firestore
///    `users/{uid}/session/current` = `{deviceId, platform, updatedAt}`.
/// 3. Semua device yang lagi aktif untuk uid yang sama akan meng-observe
///    doc itu via snapshot listener. Kalau `serverDeviceId != myDeviceId`
///    → device lama di-kick (`kicked = true`), UI di [AuthGate] tangkap
///    listener → sign-out + dialog "Sesi berakhir di perangkat ini".
///
/// Non-goals:
/// - Tidak block sign-in device baru. Justru sebaliknya: device baru
///   selalu menang, device lama otomatis logout (behavior mirip WhatsApp
///   Web / Netflix "logged in on another device").
/// - Tidak sinkron real-time chat state antar device — hanya session
///   identity. Chat history sudah di-mirror ke Firestore lewat
///   [FirebaseService.saveThread] (M7).
class DeviceSessionService {
  DeviceSessionService._();
  static final DeviceSessionService instance = DeviceSessionService._();

  static const _kDeviceIdKey = 'device_id_v1';

  String? _deviceId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  /// True kalau server bilang device lain sudah claim uid yang sama.
  final ValueNotifier<bool> kicked = ValueNotifier<bool>(false);

  /// Deterministic device ID per install. Owner boleh Clear Data untuk
  /// reset.
  Future<String> deviceId() async {
    if (_deviceId != null) return _deviceId!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kDeviceIdKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_kDeviceIdKey, id);
    }
    _deviceId = id;
    return id;
  }

  String _platformTag() {
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
    } catch (_) {}
    return 'other';
  }

  /// Klaim uid ini untuk device ini. Aman dipanggil berulang (idempotent).
  ///
  /// Return `true` kalau claim sukses (device jadi pemilik aktif),
  /// `false` kalau Firebase belum ready / gagal — sign-in tetap boleh
  /// lanjut, hanya saja proteksi single-device idle sampai next attempt.
  Future<bool> claim(String uid) async {
    if (uid.isEmpty) return false;
    final myId = await deviceId();
    final ok = await FirebaseService.instance.claimDevice(
      uid: uid,
      deviceId: myId,
      platform: _platformTag(),
    );
    if (!ok) return false;
    _listen(uid, myId);
    return true;
  }

  /// Klaim uid berdasarkan session aktif di [AuthService].
  Future<bool> claimCurrent() async {
    final uid = AuthService.instance.current?.uid ?? '';
    if (uid.isEmpty) return false;
    return claim(uid);
  }

  void _listen(String uid, String myId) {
    _sub?.cancel();
    kicked.value = false;
    final stream = FirebaseService.instance.sessionSnapshots(uid);
    if (stream == null) return;
    _sub = stream.listen((snap) {
      final data = snap.data();
      if (data == null) return;
      final serverId = (data['deviceId'] ?? '').toString();
      if (serverId.isNotEmpty && serverId != myId) {
        kicked.value = true;
      }
    }, onError: (_) {
      // Rules ketat / offline — jangan false-kick.
    });
  }

  /// Stop observing (dipanggil saat logout). TIDAK menghapus doc di
  /// server — biar device lain yang menang tetap punya klaim aktif.
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    kicked.value = false;
  }

  /// Buang klaim device ini (dipanggil saat user logout eksplisit dari
  /// UI). Kalau doc di server masih pointing ke device ini, hapus supaya
  /// device lain yang login berikutnya tidak langsung ke-kick oleh diri
  /// sendiri.
  Future<void> release(String uid) async {
    final myId = await deviceId();
    await FirebaseService.instance.releaseDeviceIfOwned(
      uid: uid,
      deviceId: myId,
    );
    await stop();
  }
}
