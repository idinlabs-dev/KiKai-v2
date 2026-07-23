import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/ai_model.dart';
import 'models_gallery_page.dart' show ModelAvatar;

/// M36 — Model Detail Page.
///
/// Menjelaskan model AI (kapabilitas, provider, best use case) dan
/// tombol CTA "Coba chat sekarang" yang men-pop kembali dengan
/// `result = true` supaya HomeShell bisa switch tab ke Chat + set model.
class ModelDetailPage extends StatelessWidget {
  final AiModel model;
  const ModelDetailPage({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    final isKikai = model.apiModelId == 'nvidia-ultra';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Detail Model',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // ── Hero ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  ModelAvatar(model: model, size: 68),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model.label,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isKikai
                              ? 'developed by idin iskandar'
                              : _providerName(model),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            const _SectionTitle('Tentang model ini'),
            const SizedBox(height: 8),
            Text(
              model.description,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                height: 1.55,
              ),
            ),

            const SizedBox(height: 22),
            const _SectionTitle('Spesifikasi'),
            const SizedBox(height: 10),
            _SpecTile(
              icon: Icons.memory_rounded,
              label: 'Max tokens',
              value: '${model.maxTokens}',
            ),
            _SpecTile(
              icon: Icons.attach_file_rounded,
              label: 'Dukung lampiran file',
              value: model.supportsFile ? 'Ya' : 'Tidak',
            ),
            _SpecTile(
              icon: Icons.build_circle_outlined,
              label: 'Dukung tools',
              value: model.supportsTools ? 'Ya' : 'Tidak',
            ),

            const SizedBox(height: 22),
            const _SectionTitle('Cocok untuk'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in _useCases(model)) _Chip(text: tag),
              ],
            ),

            const SizedBox(height: 28),

            // ── CTA ──────────────────────────────────────────────
            _CtaButton(
              label: _ctaText(model),
              onTap: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Gratis dicoba • Tanpa API key tambahan',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _providerName(AiModel m) {
    if (m.id == 'kimi' || m.label.toLowerCase() == 'kimi') {
      return 'Moonshot AI • Kimi';
    }
    final id = m.apiModelId ?? m.id;
    if (id.startsWith('glm')) return 'Z.ai • GLM Series';
    if (id.startsWith('gpt-oss')) return 'OpenAI • Open Source';
    return 'AI Inference';
  }

  static List<String> _useCases(AiModel m) {
    final id = m.apiModelId ?? m.id;
    if (id == 'nvidia-ultra') {
      return const ['Ngobrol santai', 'Coding', 'Security', 'Riset umum'];
    }
    if (m.id == 'kimi') {
      return const ['Q&A cepat', 'Ringkasan', 'Chat harian'];
    }
    if (id.startsWith('glm')) {
      return const ['Multi-bahasa', 'Penulisan panjang', 'Riset', 'Kreatif'];
    }
    if (id.startsWith('gpt-oss')) {
      return const ['General knowledge', 'Instruksi', 'Chat harian'];
    }
    return const ['General purpose'];
  }

  static String _ctaText(AiModel m) {
    final id = m.apiModelId ?? m.id;
    if (m.id == 'kimi') return 'Chat Ngebut Sekarang';
    if (id.startsWith('glm')) return 'Mulai Chat dengan GLM';
    if (id.startsWith('gpt-oss')) return 'Coba GPT-OSS Sekarang';
    if (id == 'nvidia-ultra') return 'Mulai Chat Sekarang';
    return 'Coba Chat Sekarang';
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      );
}

class _SpecTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SpecTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _CtaButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
