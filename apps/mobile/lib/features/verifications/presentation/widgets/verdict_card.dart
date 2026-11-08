import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../domain/verification_entities.dart';
import 'verdict_style.dart';

/// The verdict reveal: badge zooms in, figures follow.
class VerdictCard extends StatelessWidget {
  const VerdictCard({
    super.key,
    required this.verdict,
    required this.hint,
    required this.expected,
    required this.reported,
    required this.difference,
    this.reportedNote,
    this.reportedLabel,
    this.heroTag,
  });

  final Verdict verdict;
  final String hint;
  final String expected;
  final String reported;
  final String difference;
  final String? reportedNote;

  /// Name of the audited loyalty program, shown under the reported figure.
  final String? reportedLabel;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = VerdictStyle.of(context, verdict);
    Widget badge = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
      child: Icon(style.icon, color: theme.colorScheme.surface, size: 34),
    );
    if (heroTag != null) badge = Hero(tag: heroTag!, child: badge);
    return ZoomIn(
      duration: const Duration(milliseconds: 550),
      child: Container(
        key: const Key('verdict-card'),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: style.container,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                BounceInDown(
                  duration: const Duration(milliseconds: 800),
                  child: badge,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    style.label,
                    key: const Key('verdict-label'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: style.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FadeIn(
              delay: const Duration(milliseconds: 350),
              child: Text(
                hint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 20),
            FadeInUp(
              delay: const Duration(milliseconds: 450),
              from: 14,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Figure(label: S.expectedLabel, value: expected),
                  ),
                  Expanded(
                    child: _Figure(
                      label: S.reportedLabel,
                      value: reported,
                      note: reportedNote ?? reportedLabel,
                    ),
                  ),
                  Expanded(
                    child: _Figure(
                      label: S.differenceLabel,
                      value: difference,
                      color: style.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    this.note,
    this.color,
  });

  final String label;
  final String value;
  final String? note;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        if (note != null) Text(note!, style: theme.textTheme.labelSmall),
      ],
    );
  }
}
