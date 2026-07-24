import 'package:flutter/material.dart';

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
      extendBody: true,
      backgroundColor: AppColors.background,
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.divider, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _NavItem(
                icon: Icons.chat_bubble_outline_rounded,
                iconActive: Icons.chat_bubble_rounded,
                label: 'Chat',
                selected: page == 0,
                onTap: () => onSelectPage(0),
              ),
              _NavItem(
                icon: Icons.history_rounded,
                iconActive: Icons.history_rounded,
                label: 'History',
                selected: page == 1,
                onTap: () => onSelectPage(1),
              ),
              _KikaiButton(onTap: onKikai),
              _NavItem(
                icon: Icons.auto_awesome_outlined,
                iconActive: Icons.auto_awesome_rounded,
                label: 'Models',
                selected: page == 2,
                onTap: () => onSelectPage(2),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                iconActive: Icons.person_rounded,
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
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 26),
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
            Icon(selected ? iconActive : icon, color: color, size: 23),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
