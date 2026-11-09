import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../atoms/status_pill.dart';

/// Result headline: status chip with icon, Bodoni title, Bodoni difference
/// amount, Expected / Reported rows right-aligned and an optional equivalence.
class VerdictCard extends StatelessWidget {
  const VerdictCard({
    super.key,
    required this.kind,
    required this.statusLabel,
    required this.title,
    required this.amount,
    required this.expectedLabel,
    required this.expected,
    required this.reportedLabel,
    required this.reported,
    this.statusIcon,
    this.equivalence,
  });

  final StatusKind kind;

  /// Text of the status chip (e.g. "Underpaid").
  final String statusLabel;
  final IconData? statusIcon;

  /// Bodoni headline (e.g. "You were underpaid").
  final String title;

  /// Difference, already formatted with its sign and ISO code.
  final String amount;
  final String expectedLabel;
  final String expected;
  final String reportedLabel;
  final String reported;

  /// Optional line such as `Equivalent to USD 58.70`.
  final String? equivalence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = kind.tone(context.appColors);
    final muted = theme.colorScheme.onSurfaceVariant;
    Widget row(String label, String value) => Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: muted,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          textAlign: TextAlign.end,
          style: theme.textTheme.titleSmall?.copyWith(
            fontFeatures: appFigures,
            fontSize: 14,
          ),
        ),
      ],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusPill(kind: kind, label: statusLabel, icon: statusIcon),
            const SizedBox(height: 14),
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              amount,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: tone.fg,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Divider(color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 10),
            row(expectedLabel, expected),
            const SizedBox(height: 6),
            row(reportedLabel, reported),
            if (equivalence != null) ...[
              const SizedBox(height: 10),
              Text(
                equivalence!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: muted,
                  fontFeatures: appFigures,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
