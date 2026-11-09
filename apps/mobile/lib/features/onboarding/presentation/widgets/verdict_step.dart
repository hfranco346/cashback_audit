import 'package:animate_do/animate_do.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../verifications/domain/verification_entities.dart';
import '../../../verifications/presentation/format_reward.dart';
import 'onboarding_frame.dart';

/// Step 6: reveal of the first verdict, then Home (already configured).
class VerdictStep extends StatelessWidget {
  const VerdictStep({
    super.key,
    required this.verification,
    required this.cardName,
    required this.categoryCount,
    required this.onDetail,
    required this.onHome,
  });

  final Verification verification;
  final String cardName;
  final int categoryCount;
  final VoidCallback onDetail;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final v = verification;
    final verdict = v.verdict ?? Verdict.match;
    final kind = switch (verdict) {
      Verdict.match => StatusKind.ok,
      Verdict.underpaid => StatusKind.error,
      Verdict.overpaid => StatusKind.overpaid,
    };
    final currency = v.resolvedRewardCurrency;
    String money(Decimal? d) =>
        d == null ? '—' : formatReward(d, v.unit, currency: currency);
    final diff = v.difference;
    final diffText = diff == null
        ? '—'
        : '${diff > Decimal.zero
                  ? '+'
                  : diff < Decimal.zero
                  ? '–'
                  : ''}'
              '${formatReward(diff.abs(), v.unit, currency: currency)}';
    final lines = [
      for (final b in v.breakdown)
        if (b.expectedReward > Decimal.zero && !b.isBase) b,
    ].take(3);
    return OnboardingFrame(
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
            key: const Key('onb-detail'),
            label: l10n.onbSeeDetail,
            onPressed: onDetail,
          ),
          TextButton(
            key: const Key('onb-home'),
            onPressed: onHome,
            child: Text(l10n.onbGoHome),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          FadeIn(
            child: Text(
              l10n.onbFirstVerification.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: context.appColors.brass,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ZoomIn(
            duration: const Duration(milliseconds: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusPill(
                  kind: kind,
                  label: switch (verdict) {
                    Verdict.match => l10n.onbVerdictStatusMatch,
                    Verdict.underpaid => l10n.onbVerdictStatusUnder,
                    Verdict.overpaid => l10n.onbVerdictStatusOver,
                  },
                ),
                const SizedBox(height: 10),
                Text(switch (verdict) {
                  Verdict.match => l10n.verdictMatch,
                  Verdict.underpaid => l10n.verdictUnderpaid,
                  Verdict.overpaid => l10n.verdictOverpaid,
                }, style: theme.textTheme.displaySmall),
                const SizedBox(height: 10),
                Text(
                  diffText,
                  key: const Key('onb-verdict-amount'),
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: kind.tone(context.appColors).fg,
                    fontFeatures: appFigures,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FadeInUp(
            delay: const Duration(milliseconds: 500),
            from: 14,
            child: Card(
              child: Row(
                children: [
                  Expanded(
                    child: _Figure(
                      label: l10n.expectedLabel,
                      value: money(v.expectedAmount),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 52,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  Expanded(
                    child: _Figure(
                      label: l10n.reportedLabel,
                      value: money(v.reported?.amount),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FadeInUp(
            delay: const Duration(milliseconds: 800),
            from: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final b in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• ${l10n.onbContributes(b.categoryName ?? '', money(b.expectedReward), b.transactionCount)}',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FadeInUp(
            delay: const Duration(milliseconds: 1100),
            from: 14,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.onbSavedSummary(cardName, categoryCount),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFeatures: appFigures,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
