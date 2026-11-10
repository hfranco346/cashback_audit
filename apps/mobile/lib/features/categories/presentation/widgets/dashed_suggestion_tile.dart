import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// One-tap suggestion (`.sug`): dashed hairline border, a primary `+` and the
/// label. Presentational.
class DashedSuggestionTile extends StatelessWidget {
  const DashedSuggestionTile({
    super.key,
    required this.label,
    required this.onTap,
    this.added = false,
  });

  final String label;
  final VoidCallback? onTap;

  /// Already created: shows a check instead of the `+` and ignores taps.
  final bool added;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: scheme.outlineVariant,
            radius: AppRadii.field,
          ),
          child: InkWell(
            onTap: added ? null : onTap,
            borderRadius: BorderRadius.circular(AppRadii.field),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    if (added)
                      Icon(Icons.check_rounded, size: 18, color: scheme.primary)
                    else
                      Text(
                        '+',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 18,
                          color: scheme.primary,
                        ),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontSize: 14,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.5),
          Radius.circular(radius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 4), paint);
        distance += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
