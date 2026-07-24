import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../models/ai_model.dart';
import '../../services/ads_service.dart';
import '../chat/chat_controller.dart';
import '../chat/chat_screen.dart';
import '../history/history_screen.dart';
import '../models/models_gallery_page.dart';
import '../profile/profile_screen.dart';

/// KiKai — Shell utama dengan bottom navigation 5-slot.
///
/// Layout: **Chat · History · [Kikai] · Missions · Profile**.
/// Tombol tengah "Kikai" = brand button → buka Chat + mulai percakapan baru.
/// Settings diakses dari Profile (ikon gear), Notifications dari Chat (bell).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final ChatController _controller = ChatController();
  int _page = 0; // 0=Chat 1=History 2=Missions 3=Profile

  // M24 — Interstitial 60 detik setelah masuk Home (sekali per sesi).
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 60), () {
      if (!mounted) return;
      AdsService.instance.showHomeInterstitialOnce();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goChat() => setState(() => _page = 0);

  void _newChat() {
    _controller.newDraft();
    setState(() => _page = 0);
  }

  // M24 — first-time tap tab Profile → interstitial.
  void _selectPage(int p) {
    if (p == 3) {
      AdsService.instance.showProfileInterstitialOnce();
    }
    setState(() => _page = p);
  }

  void _tryModel(AiModel m) {
    _controller.newDraft();
    _controller.setModel(m);
    setState(() => _page = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _page,
        children: [
          ChatScreen(controller: _controller),
          HistoryScreen(controller: _controller, onOpenThread: _goChat),
          ModelsGalleryPage(onTryModel: _tryModel),
          ProfileScreen(controller: _controller),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        page: _page,
        onSelectPage: _selectPage,
        onKikai: _newChat,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int page;
  final ValueChanged<int> onSelectPage;
  final VoidCallback onKikai;
  const _BottomNav({
    required this.page,
    required this.onSelectPage,
    required this.onKikai,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 78,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _NavItem(
                icon: LucideIcons.messageCircle,
                iconActive: LucideIcons.messageCircle,
                label: 'Chat',
                selected: page == 0,
                onTap: () => onSelectPage(0),
              ),
              _NavItem(
                icon: LucideIcons.history,
                iconActive: LucideIcons.history,
                label: 'History',
                selected: page == 1,
                onTap: () => onSelectPage(1),
              ),
              _KikaiButton(onTap: onKikai),
              _NavItem(
                icon: LucideIcons.sparkles,
                iconActive: LucideIcons.sparkles,
                label: 'Models',
                selected: page == 2,
                onTap: () => onSelectPage(2),
              ),
              _NavItem(
                icon: LucideIcons.user,
                iconActive: LucideIcons.user,
                label: 'Profile',
                selected: page == 3,
                onTap: () => onSelectPage(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KikaiButton extends StatelessWidget {
  final VoidCallback onTap;
  const _KikaiButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.22),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(LucideIcons.plus,
                  color: AppColors.surface, size: 30),
            ),
            const SizedBox(height: 4),
            const Text(
              'Kikai',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData iconActive;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.iconActive,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.textPrimary : AppColors.navInactive;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? iconActive : icon, color: color, size: 27),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
