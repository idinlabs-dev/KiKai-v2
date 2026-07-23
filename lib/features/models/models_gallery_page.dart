import 'package:flutter/material.dart';

import '../../core/constants/ai_models.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ai_model.dart';
import 'model_detail_page.dart';

/// M36 — Models Gallery
///
/// Halaman grid semua model AI yang tersedia (KiKai personas + model
/// eksternal via proxy NVIDIA: GLM 5.2, Kimi K2.6, DeepSeek V4 Pro/Flash,
/// GPT-OSS 20B). User pilih model → detail → coba chat.
class ModelsGalleryPage extends StatelessWidget {
  /// Callback saat user memilih model & tekan "Coba chat sekarang".
  final ValueChanged<AiModel> onTryModel;

  const ModelsGalleryPage({super.key, required this.onTryModel});

  @override
  Widget build(BuildContext context) {
    final personas = kKikaiPersonas;
    final external = kExternalModels;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _HeroHeader()),
            _SectionHeader(
              title: 'KiKai',
              subtitle: 'Model utama KiKai — serba-bisa, dev by Idin Iskandar',
            ),
            _ModelsGrid(
              models: personas,
              onTap: (m) => _openDetail(context, m),
            ),
            _SectionHeader(
              title: 'Model AI Lainnya',
              subtitle: 'Coba model AI populer langsung di sini',
            ),
            _ModelsGrid(
              models: external,
              onTap: (m) => _openDetail(context, m),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, AiModel model) async {
    final tapped = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ModelDetailPage(model: model),
      ),
    );
    if (tapped == true) onTryModel(model);
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: Text(
              'AI Studio',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: const [
                Icon(Icons.bolt_rounded,
                    color: Colors.white, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Semua AI dalam satu app',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Pilih model favorit kamu, mulai chat kapan aja — gratis.',
                        style: TextStyle(
                          color: Colors.white70,
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
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelsGrid extends StatelessWidget {
  final List<AiModel> models;
  final ValueChanged<AiModel> onTap;
  const _ModelsGrid({required this.models, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) => ModelCard(model: models[i], onTap: () => onTap(models[i])),
          childCount: models.length,
        ),
      ),
    );
  }
}

class ModelCard extends StatelessWidget {
  final AiModel model;
  final VoidCallback onTap;
  const ModelCard({super.key, required this.model, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ModelAvatar(model: model, size: 52),
              const Spacer(),
              Text(
                model.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                model.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _providerLabel(model),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 16, color: AppColors.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _providerLabel(AiModel m) {
    if (m.apiModelId == 'nvidia-ultra') return 'KiKai';
    if (m.id == 'kimi') return 'Moonshot';
    final id = m.apiModelId ?? m.id;
    if (id.startsWith('glm')) return 'Z.AI';
    if (id.startsWith('gpt-oss')) return 'OpenAI';
    return 'AI';
  }
}

/// Avatar model — pakai iconAsset kalau ada, kalau tidak fallback ke
/// tile hitam dengan inisial (monochrome brand).
class ModelAvatar extends StatelessWidget {
  final AiModel model;
  final double size;
  const ModelAvatar({super.key, required this.model, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final asset = model.iconAsset;
    if (asset != null && asset.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final initial = model.label.isNotEmpty ? model.label[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
