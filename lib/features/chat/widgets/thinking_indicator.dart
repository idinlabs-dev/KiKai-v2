import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Menampilkan "alur berfikir" Kikai saat AI mulai memproses pesan user.
///
/// - Ikon otak dengan aura berdenyut.
/// - Label utama "Berfikir…" dengan efek shimmer.
/// - Sub-label yang berganti tiap ~1.4 detik: "Menganalisis pertanyaan",
///   "Mencari referensi", "Menyusun jawaban", dst.
///
/// Widget ini otomatis disable timer-nya saat di-dispose.
class ThinkingIndicator extends StatefulWidget {
  const ThinkingIndicator({super.key});

  static const List<String> _steps = [
    'Menganalisis pertanyaan…',
    'Menyusun konteks…',
    'Mencari referensi relevan…',
    'Menimbang pilihan jawaban…',
    'Menyusun respons…',
    'Memeriksa ulang…',
  ];

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _shimmer;
  Timer? _stepTimer;
  int _stepIndex = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _stepTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (!mounted) return;
      setState(() {
        _stepIndex = (_stepIndex + 1) % ThinkingIndicator._steps.length;
      });
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _pulse.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _PulsingBrain(pulse: _pulse),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerText(
                  text: 'Berfikir…',
                  controller: _shimmer,
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.25),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    ThinkingIndicator._steps[_stepIndex],
                    key: ValueKey<int>(_stepIndex),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                    ),
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

class _PulsingBrain extends StatelessWidget {
  final AnimationController pulse;
  const _PulsingBrain({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) {
        final t = pulse.value;
        final glow = 4.0 + 8.0 * t;
        final scale = 0.94 + 0.10 * t;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.textPrimary.withOpacity(0.06),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withOpacity(0.18 * t),
                  blurRadius: glow,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: const Icon(
              Icons.psychology_alt_rounded,
              size: 16,
              color: AppColors.textPrimary,
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerText extends StatelessWidget {
  final String text;
  final AnimationController controller;
  const _ShimmerText({required this.text, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final v = controller.value;
        return ShaderMask(
          shaderCallback: (rect) {
            final dx = rect.width;
            return LinearGradient(
              begin: Alignment(-1 + 2 * v - 0.3, 0),
              end: Alignment(-1 + 2 * v + 0.3, 0),
              colors: const [
                AppColors.textMuted,
                AppColors.textPrimary,
                AppColors.textMuted,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(Rect.fromLTWH(0, 0, dx, rect.height));
          },
          blendMode: BlendMode.srcIn,
          child: Text(
            text,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2 + math.sin(v * math.pi * 2) * 0.05,
            ),
          ),
        );
      },
    );
  }
}
