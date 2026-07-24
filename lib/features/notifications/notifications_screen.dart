import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../models/app_notification.dart';
import '../../services/ads_service.dart';
import '../../services/notifications_service.dart';
import 'notification_detail_page.dart';

/// M21 — Notifications tab.
///
/// Menampilkan gabungan **broadcast admin** + **notifikasi lokal** user
/// (mis. daily check-in sukses, misi disetujui). Dengarkan
/// [NotificationsService.combinedStream] realtime.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Best-effort: tandai read pas user buka tab.
      NotificationsService.instance.markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Notifikasi'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<AppNotification>>(
          stream: NotificationsService.instance.combinedStream(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = snap.data ?? const <AppNotification>[];
            if (list.isEmpty) {
              return const _Empty();
            }
            // M24 — sisip Native AdMob tiap 3 notifikasi.
            const int adEvery = 3;
            final adCount = list.length ~/ adEvery;
            final total = list.length + adCount;
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              itemCount: total,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                // Setiap (adEvery+1)-th slot adalah iklan.
                final block = adEvery + 1;
                if (i % block == adEvery) {
                  return const _NativeAdTile();
                }
                final notifIndex = i - (i ~/ block);
                if (notifIndex >= list.length) {
                  return const SizedBox.shrink();
                }
                return _NotifTile(item: list[notifIndex]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final AppNotification item;
  const _NotifTile({required this.item});

  IconData _iconFor() {
    if (item.isBroadcast) return LucideIcons.megaphone;
    switch (item.type) {
      case 'streak': return LucideIcons.flame;
      case 'mission': return LucideIcons.badgeCheck;
      default: return LucideIcons.bell;
    }
  }

  Color _colorFor() {
    if (item.isBroadcast) return AppColors.primary;
    switch (item.type) {
      case 'streak': return AppColors.warning;
      case 'mission': return AppColors.success;
      default: return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor();
    final ts = item.createdAt.millisecondsSinceEpoch == 0
        ? '-'
        : DateFormat('dd MMM • HH:mm').format(item.createdAt.toLocal());
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => NotificationDetailPage(item: item),
        )),
        child: Container(
       padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
         borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 58, height: 58,
          decoration: BoxDecoration(
            color: AppColors.iconTile,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(_iconFor(), color: color, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    item.title.isEmpty ? '(tanpa judul)' : item.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (item.isBroadcast)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.softChip,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('ADMIN',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        )),
                  ),
              ]),
              if (item.body.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  item.body,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(ts,
                  style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 13)),
            ],
          ),
        ),
      ]),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.bellOff,
              size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text('Belum ada notifikasi',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 6),
          const Text(
            'Broadcast admin & aktivitas misi/streak kamu akan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
        ]),
      ),
    );
  }
}


// M24 — Native AdMob tile untuk list notifikasi.
class _NativeAdTile extends StatefulWidget {
  const _NativeAdTile();
  @override
  State<_NativeAdTile> createState() => _NativeAdTileState();
}

class _NativeAdTileState extends State<_NativeAdTile> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _ad = NativeAd(
      adUnitId: AdsService.nativeNotifUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: AppColors.surfaceElevated,
        cornerRadius: 28,
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) {
      return const SizedBox.shrink();
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 320, maxHeight: 400),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(28),
      ),
      child: AdWidget(ad: _ad!),
    );
  }
}
