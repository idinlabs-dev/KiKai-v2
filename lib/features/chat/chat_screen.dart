import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/chat_message.dart';
import '../../services/skills_service.dart';
import '../notifications/notifications_screen.dart';
import 'chat_controller.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_composer.dart';
import 'widgets/model_selector.dart';
import 'widgets/skill_selector.dart';

/// KiKai — Chat tab. Header: notifikasi · model pill · new chat.
class ChatScreen extends StatefulWidget {
  final ChatController controller;
  const ChatScreen({super.key, required this.controller});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatController _controller = widget.controller;
  final ScrollController _scroll = ScrollController();

  static const List<String> _suggestedPrompts = [
    'Jelaskan konsep async/await di Dart dengan analogi sederhana.',
    'Bikin outline artikel blog tentang produktivitas developer.',
    'Review snippet kode ini dan kasih saran perbaikan.',
    'Terjemahin paragraf berikut ke bahasa Indonesia yang natural.',
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await SkillsService.instance.load();
      if (mounted) setState(() {});
      await _controller.loadInitial();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _scroll.dispose();
    super.dispose();
  }

  String? _lastError;

  void _onControllerChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });

    final err = _controller.error;
    if (err != null && err != _lastError) {
      _lastError = err;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(err)));
      _controller.clearError();
    } else if (err == null) {
      _lastError = null;
    }
  }

  Future<void> _handleSend(String text) async {
    await _controller.sendUserMessage(text);
  }

  Future<void> _openModelSelector() async {
    final chosen = await showModelSelector(
      context: context,
      current: _controller.model,
    );
    if (chosen != null) _controller.setModel(chosen);
  }

  Future<void> _openSkillSelector() async {
    final chosen = await showSkillSelector(
      context: context,
      currentId: SkillsService.instance.activeSkill,
    );
    if (chosen != null) {
      await SkillsService.instance.setActive(chosen);
      if (mounted) setState(() {});
    }
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Column(
              children: [
                _ChatHeader(
                  modelLabel: _controller.model.label,
                  onModelTap: _openModelSelector,
                  skillOption: SkillsService.instance.activeOption,
                  onSkillTap: _openSkillSelector,
                  onNotifications: _openNotifications,
                  onNewChat: _controller.newDraft,
                ),
                Expanded(
                  child: _controller.isEmpty
                      ? _EmptyState(
                          prompts: _suggestedPrompts,
                          onPromptTap: _handleSend,
                        )
                      : _MessageList(
                          scroll: _scroll,
                          messages: _controller.messages,
                          onFollowUpTap: _handleSend,
                        ),
                ),
                if (_controller.webStatus != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _controller.webStatus!,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                MessageComposer(
                  isSending: _controller.isSending,
                  onSend: _handleSend,
                  onStop: _controller.stopGenerating,
                  webSearchEnabled: _controller.webSearchEnabled,
                  onToggleWebSearch: _controller.toggleWebSearch,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final String modelLabel;
  final VoidCallback onModelTap;
  final SkillOption skillOption;
  final VoidCallback onSkillTap;
  final VoidCallback onNotifications;
  final VoidCallback onNewChat;

  const _ChatHeader({
    required this.modelLabel,
    required this.onModelTap,
    required this.skillOption,
    required this.onSkillTap,
    required this.onNotifications,
    required this.onNewChat,
  });

  @override
  Widget build(BuildContext context) {
    final skillActive = skillOption.id != SkillsService.kSkillNone;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onNotifications,
            icon: const Icon(Icons.notifications_none_rounded,
                color: AppColors.textPrimary),
            tooltip: 'Notifikasi',
          ),
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HeaderPill(
                    onTap: onModelTap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          modelLabel,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 20, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  _HeaderPill(
                    onTap: onSkillTap,
                    highlighted: skillActive,
                    tooltip: 'Skill: ${skillOption.label}',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          skillOption.icon,
                          size: 16,
                          color: skillActive
                              ? AppColors.surface
                              : AppColors.textPrimary,
                        ),
                        if (skillActive) ...[
                          const SizedBox(width: 6),
                          Text(
                            skillOption.label,
                            style: const TextStyle(
                              color: AppColors.surface,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onNewChat,
            icon: const Icon(Icons.edit_square, color: AppColors.textPrimary),
            tooltip: 'Percakapan baru',
          ),
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool highlighted;
  final String? tooltip;
  const _HeaderPill({
    required this.child,
    required this.onTap,
    this.highlighted = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final content = Material(
      color: highlighted ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: highlighted ? AppColors.primary : AppColors.divider,
            ),
          ),
          child: child,
        ),
      ),
    );
    if (tooltip == null) return content;
    return Tooltip(message: tooltip!, child: content);
  }
}

class _MessageList extends StatelessWidget {
  final ScrollController scroll;
  final List<ChatMessage> messages;
  final ValueChanged<String> onFollowUpTap;
  const _MessageList({
    required this.scroll,
    required this.messages,
    required this.onFollowUpTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: messages.length,
      itemBuilder: (_, i) {
        final m = messages[i];
        String? topic;
        // Ambil topic dari user message tepat sebelumnya untuk SEMUA
        // pesan assistant (bukan hanya yang sedang streaming) supaya
        // kartu "Riset selesai" bisa muncul dengan judul yang tepat.
        if (m.role == ChatRole.assistant) {
          for (var j = i - 1; j >= 0; j--) {
            if (messages[j].role == ChatRole.user) {
              topic = messages[j].content;
              break;
            }
          }
        }
        // M40 — chip follow-up hanya diberi callback pada pesan assistant
        // paling terakhir supaya user tidak "menjawab" bubble lama.
        final isLastAssistant = m.role == ChatRole.assistant &&
            i == messages.length - 1;
        return MessageBubble(
          message: m,
          researchTopic: topic,
          onFollowUpTap: isLastAssistant ? onFollowUpTap : null,
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final List<String> prompts;
  final ValueChanged<String> onPromptTap;
  const _EmptyState({required this.prompts, required this.onPromptTap});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      children: [
        const SizedBox(height: 20),
        const Center(child: KAvatar(size: 64)),
        const SizedBox(height: 20),
        const Text(
          'Halo, aku Kikai',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tanya apa saja — coding, nulis, riset, atau sekadar ngobrol.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 28),
        for (final p in prompts) ...[
          _PromptCard(text: p, onTap: () => onPromptTap(p)),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _PromptCard extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _PromptCard({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_outward_rounded,
                  size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
