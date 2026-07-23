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

/// KiKai — Shell utama dengan bottom navigation.
///
/// Layout: **Chat · History · [KiKai] · Models · Profile**.
/// Tombol tengah = brand button → mulai draft baru & buka Chat.
/// M43 — bottom nav pakai lucide icons + polished pill.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final ChatController _controller = ChatController();
  int _page = 0;

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
          height: 68,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _NavItem(
                icon: LucideIcons.messageSquare,
                label: 'Chat',
                selected: page == 0,
                onTap: () => onSelectPage(0),
              ),
              _NavItem(
                icon: LucideIcons.history,
                label: 'History',
                selected: page == 1,
                onTap: () => onSelectPage(1),
              ),
              _KikaiButton(onTap: onKikai),
              _NavItem(
                icon: LucideIcons.sparkles,
                label: 'Models',
                selected: page == 2,
                onTap: () => onSelectPage(2),
              ),
              _NavItem(
                icon: LucideIcons.user,
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
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowStrong,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(LucideIcons.plus,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(height: 4),
            const Text(
              'KiKai',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
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
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
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
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
