import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/theme/app_theme.dart';
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
    this.expectedNote,
    this.heroTag,
  });

  final Verdict verdict;
  final String hint;
  final String expected;
  final String reported;
  final String difference;
  final String? reportedNote;

  /// Secondary line under the expected figure, e.g. "Equivale a HNL 589.61"
  /// when the reward currency differs from the card's.
  final String? expectedNote;

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
              child: Container(
                key: const Key('verdict-figures'),
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _FigureRow(
                      label: S.expectedLabel,
                      value: expected,
                      note: expectedNote,
                      noteKey: const Key('expected-equivalent'),
                    ),
                    const SizedBox(height: 10),
                    _FigureRow(
                      label: S.reportedLabel,
                      value: reported,
                      note: reportedNote ?? reportedLabel,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(
                        height: 1,
                        color: style.color.withValues(alpha: 0.25),
                      ),
                    ),
                    _FigureRow(
                      label: S.differenceLabel,
                      value: difference,
                      color: style.color,
                      emphasized: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One line of the breakdown: label (and optional note) on the left, amount
/// right-aligned so figures line up regardless of currency or length.
class _FigureRow extends StatelessWidget {
  const _FigureRow({
    required this.label,
    required this.value,
    this.note,
    this.noteKey,
    this.color,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final String? note;
  final Key? noteKey;
  final Color? color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle =
        (emphasized ? theme.textTheme.titleLarge : theme.textTheme.titleMedium)
            ?.copyWith(
              fontFamily: emphasized ? AppFonts.display : null,
              fontSize: emphasized ? 30 : null,
              color: color ?? theme.colorScheme.onSurface,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style:
                    (emphasized
                            ? theme.textTheme.titleSmall
                            : theme.textTheme.bodyMedium)
                        ?.copyWith(
                          color: emphasized
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant,
                        ),
              ),
              if (note != null)
                Text(
                  note!,
                  key: noteKey,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(value, style: valueStyle, textAlign: TextAlign.right),
            ),
          ),
        ),
      ],
    );
  }
}
