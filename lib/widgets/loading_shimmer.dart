import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Loading shimmer sederhana (tanpa dependency `shimmer`) — dipakai
/// list history & thread tile di M2. Untuk M0 hanya export widget.
class LoadingShimmer extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const LoadingShimmer({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2 * _ctrl.value, 0),
              end: Alignment(1.0 + 2 * _ctrl.value, 0),
              colors: const [
                AppColors.surfaceElevated,
                AppColors.surfaceHigh,
                AppColors.surfaceElevated,
              ],
            ),
          ),
        );
      },
    );
  }
}
