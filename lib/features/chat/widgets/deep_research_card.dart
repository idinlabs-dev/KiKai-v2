import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../research_report_page.dart';

/// M38 — Deep Research card (Gemini-style).
///
/// Dua mode:
///  - `active = true` → **Plan card** (rencana riset multi-tahap
///    dengan tombol "Edit rencana" + "Mulai penelitian" ala Gemini).
///  - `active = false` → **Completed card** (kartu ringkas dengan ikon
///    globe, judul "Riset {topic}", tanggal, tombol "Buka") yang
///    menavigasi ke `ResearchReportPage` menampilkan laporan penuh.
///
/// Kartu ini murni presentational — tombol "Mulai penelitian" tidak
/// memicu API karena streaming sudah dimulai otomatis oleh controller.
class DeepResearchCard extends StatefulWidget {
  final String topic;
  final bool active;

  /// Isi laporan (markdown) — hanya dipakai saat `active = false` untuk
  /// dibuka di [ResearchReportPage].
  final String? reportMarkdown;

  /// Waktu selesai untuk badge tanggal di kartu completed.
  final DateTime? completedAt;

  const DeepResearchCard({
    super.key,
    required this.topic,
    required this.active,
    this.reportMarkdown,
    this.completedAt,
  });

  @override
  State<DeepResearchCard> createState() => _DeepResearchCardState();
}

class _DeepResearchCardState extends State<DeepResearchCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  Timer? _tick;
  int _step = 0; // 0..3 highlight index

  @override
  void initState() {
    super.initState();
    if (widget.active) _startTicker();
  }

  @override
  void didUpdateWidget(covariant DeepResearchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && _tick == null) _startTicker();
    if (!widget.active) {
      _tick?.cancel();
      _tick = null;
    }
  }

  void _startTicker() {
    _tick = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() => _step = (_step + 1) % 4);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return _buildCompletedCard(context);
    return _buildPlanCard(context);
  }

  // ── Plan (streaming) ────────────────────────────────────────────────
  Widget _buildPlanCard(BuildContext context) {
    final title = widget.topic.trim().isEmpty
        ? 'Rencana Riset'
        : 'Riset ${_shortTopic(widget.topic)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10, top: 2),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FadeTransition(
                opacity: _pulse,
                child: const Icon(
                  Icons.hub_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _PlanSection(
            icon: Icons.travel_explore_rounded,
            title: 'Situs Riset',
            active: _step == 0,
            body:
                '(1) Mengumpulkan sumber relevan multi-domain (artikel, '
                'dokumen, situs resmi, forum diskusi).\n'
                '(2) Menyaring hasil berdasarkan kredibilitas & '
                'kesegaran informasi.',
          ),
          _PlanSection(
            icon: Icons.insights_rounded,
            title: 'Analisis Hasil',
            active: _step == 1,
            body: null,
          ),
          _PlanSection(
            icon: Icons.description_rounded,
            title: 'Buat Laporan',
            active: _step == 2,
            body: null,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: _step == 3
                      ? AppColors.primary
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Siap dalam beberapa menit',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _GhostButton(
                  icon: Icons.edit_outlined,
                  label: 'Edit rencana',
                  onTap: () => _showEditPlanNotice(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SolidButton(
                  icon: Icons.play_arrow_rounded,
                  label: 'Mulai penelitian',
                  onTap: null, // sudah otomatis berjalan
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Completed (report open) ─────────────────────────────────────────
  Widget _buildCompletedCard(BuildContext context) {
    final title = widget.topic.trim().isEmpty
        ? 'Laporan Riset'
        : 'Riset ${_shortTopic(widget.topic)}';
    final ts = widget.completedAt ?? DateTime.now();
    final dateLabel = _shortDate(ts);

    return Container(
      margin: const EdgeInsets.only(bottom: 6, top: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openReport(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: const Icon(
                        Icons.public_rounded,
                        size: 22,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Laporan riset · $dateLabel',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _PillButton(
                      icon: Icons.open_in_new_rounded,
                      label: 'Buka',
                      onTap: () => _openReport(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openReport(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResearchReportPage(
          topic: widget.topic,
          markdown: widget.reportMarkdown ?? '',
          completedAt: widget.completedAt ?? DateTime.now(),
        ),
      ),
    );
  }

  void _showEditPlanNotice(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Rencana otomatis — segera hadir untuk diedit.'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  String _shortTopic(String s) {
    final line = s.split('\n').first.trim();
    if (line.length <= 60) return line;
    return '${line.substring(0, 60).trimRight()}…';
  }

  String _shortDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final local = d.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}

class _PlanSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final bool active;
  const _PlanSection({
    required this.icon,
    required this.title,
    required this.body,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary.withOpacity(0.12)
                  : AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active ? AppColors.primary : AppColors.divider,
                width: active ? 1.2 : 1,
              ),
            ),
            child: Icon(
              icon,
              size: 15,
              color: active ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight:
                          active ? FontWeight.w800 : FontWeight.w700,
                    ),
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    body!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small buttons ────────────────────────────────────────────────────

class _GhostButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _GhostButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.textPrimary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SolidButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _SolidButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AppColors.surface),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.surface,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.surface),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.surface,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
