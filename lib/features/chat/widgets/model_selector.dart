import 'package:flutter/material.dart';

import '../../../core/constants/ai_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/ai_model.dart';
import '../../../models/user_entitlements.dart';
import '../../../services/auth_service.dart';
import '../../../services/creator_mission_service.dart';
import '../../../services/streak_service.dart';
import '../../mission/mission_page.dart';

/// M3 — Bottom sheet pemilih model AI.
///
/// **M21 — Dynamic gating**: setiap tile menghitung status unlock
/// berdasarkan [UserEntitlements] (Firestore `users/{uid}`) + streak
/// harian lokal. Model yang locked menampilkan gembok + tap arahin ke
/// Mission Center.
Future<AiModel?> showModelSelector({
  required BuildContext context,
  required AiModel current,
}) {
  return showModalBottomSheet<AiModel>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => _ModelSelectorSheet(current: current),
  );
}

/// M21 — Aturan gating tunggal, dipakai UI + validator saat send message.
bool isModelUnlocked(
  AiModel m, {
  UserEntitlements? ent,
  int streakCount = 0,
}) {
  // M24 — Semua model dibuka. Monetisasi via AdMob (lihat AdsService).
  return true;
}

class _ModelSelectorSheet extends StatefulWidget {
  final AiModel current;
  const _ModelSelectorSheet({required this.current});
  @override
  State<_ModelSelectorSheet> createState() => _ModelSelectorSheetState();
}

class _ModelSelectorSheetState extends State<_ModelSelectorSheet> {
  UserEntitlements _ent = const UserEntitlements();
  int _streak = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await StreakService.instance.load();
    _streak = StreakService.instance.state.count;
    final uid = AuthService.instance.current?.uid ?? '';
    if (uid.isNotEmpty) {
      try {
        _ent = await CreatorMissionService.instance.fetchEntitlements(uid);
      } catch (_) {}
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42, height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 4),
              child: Text('Pilih mode',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Ganti gaya jawab KiKai — pilih mode sesuai kebutuhan kamu.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: kAiModels.length,
                  itemBuilder: (_, i) {
                    final m = kAiModels[i];
                    final unlocked =
                        isModelUnlocked(m, ent: _ent, streakCount: _streak);
                    return _ModelTile(
                      model: m,
                      selected: m.id == widget.current.id,
                      locked: !unlocked,
                      onTap: () async {
                        if (!unlocked) {
                          Navigator.of(context).pop();
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const MissionPage()),
                          );
                          return;
                        }
                        Navigator.of(context).pop(m);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  final AiModel model;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;
  const _ModelTile({
    required this.model,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppColors.surfaceHigh : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.divider,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ModelIcon(model: model, locked: locked),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(
                            model.label,
                            style: TextStyle(
                              color: locked
                                  ? AppColors.textMuted
                                  : AppColors.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (locked)
                          _Badge(
                            icon: Icons.lock_rounded,
                            text: model.lockedReason.isEmpty
                                ? 'LOCKED'
                                : model.lockedReason.toUpperCase(),
                            color: AppColors.warning,
                          )
                        else if (selected)
                          const _Badge(text: 'Aktif', color: AppColors.primary),
                      ]),
                      const SizedBox(height: 4),
                      if (model.description.isNotEmpty)
                        Text(
                          model.description,
                          style: TextStyle(
                            color: locked
                                ? AppColors.textMuted
                                : AppColors.textSecondary,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData? icon;
  final String text;
  final Color color;
  const _Badge({this.icon, required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.55)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
        ],
        Text(text,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            )),
      ]),
    );
  }
}

/// M23.1 — Ikon tile model. Kalau [AiModel.iconAsset] tersedia, render
/// PNG bulat dengan halo gradient tipis; kalau tidak → fallback hexagon
/// brand gradient (perilaku lama). Saat locked → overlay gembok samar.
class _ModelIcon extends StatelessWidget {
  final AiModel model;
  final bool locked;
  const _ModelIcon({required this.model, required this.locked});

  @override
  Widget build(BuildContext context) {
    final asset = model.iconAsset;
    final hasAsset = asset != null && asset.isNotEmpty;

    final Widget core = hasAsset
        ? ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Container(
              width: 38,
              height: 38,
              color: AppColors.surfaceHigh,
              child: Image.asset(
                asset,
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.hexagon_rounded,
                      size: 20, color: Colors.white),
                ),
              ),
            ),
          )
        : Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.hexagon_rounded,
                size: 20, color: Colors.white),
          );

    if (!locked) return core;

    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: 0.55, child: core),
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.6)),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.lock_rounded,
              size: 13, color: Colors.white),
        ),
      ],
    );
  }
}
