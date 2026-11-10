import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../cards/domain/card_entities.dart';
import '../../domain/verification_entities.dart';
import '../format_reward.dart';

/// `current - previous + redeemed + expired = earned`, one amount per row,
/// right aligned with tabular figures. Rows without data are left out, so a
/// statement that prints the earned amount shows just that line.
class RewardDerivation extends StatelessWidget {
  const RewardDerivation({
    super.key,
    required this.unit,
    required this.currency,
    this.current,
    this.previous,
    this.redeemed,
    this.expired,
    this.earned,
  });

  final RewardUnit unit;
  final String currency;
  final Decimal? current;
  final Decimal? previous;
  final Decimal? redeemed;
  final Decimal? expired;
  final Decimal? earned;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.appColors;
    final muted = theme.colorScheme.onSurfaceVariant;
    String fmt(Decimal d) => formatReward(d, unit, currency: currency);

    Widget row(Key key, String label, String value, {Color? color}) => Row(
      key: key,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
        ),
        const SizedBox(width: 12),
        AmountText.text(
          value,
          color: color,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    final negative = earned != null && earned! < Decimal.zero;
    final rows = <Widget>[
      if (current != null)
        row(
          const Key('derivation-current'),
          l10n.reportingCurrentBalance,
          fmt(current!),
        ),
      if (previous != null)
        row(
          const Key('derivation-previous'),
          '− ${l10n.reportingPreviousBalance}',
          fmt(previous!),
        ),
      if (redeemed != null && redeemed! != Decimal.zero)
        row(
          const Key('derivation-redeemed'),
          '+ ${l10n.reportingRedeemed}',
          fmt(redeemed!),
        ),
      if (expired != null && expired! != Decimal.zero)
        row(
          const Key('derivation-expired'),
          '+ ${l10n.reportingExpired}',
          fmt(expired!),
        ),
    ];
    return Column(
      key: const Key('reward-derivation'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in rows) ...[r, const SizedBox(height: 6)],
        if (earned != null) ...[
          if (rows.isNotEmpty) ...[
            Divider(color: theme.colorScheme.outlineVariant, height: 12),
            const SizedBox(height: 4),
          ],
          Row(
            key: const Key('derivation-earned'),
            children: [
              Expanded(
                child: Text(
                  '= ${l10n.reportingEarned}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              AmountText.text(
                fmt(earned!),
                color: negative ? colors.error.fg : null,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Result screens: how a cumulative balance became the audited figure, with
/// where the previous balance came from.
class RewardDerivationSection extends StatelessWidget {
  const RewardDerivationSection({
    super.key,
    required this.reporting,
    required this.unit,
    required this.currency,
  });

  final RewardReportingResult reporting;
  final RewardUnit unit;
  final String currency;

  String? _source(AppLocalizations l10n) =>
      switch (reporting.previousBalanceSource) {
        PreviousBalanceSource.statement => l10n.reportingPrevSourceStatement,
        PreviousBalanceSource.previousVerification =>
          l10n.reportingPrevSourceVerification,
        PreviousBalanceSource.user => l10n.reportingPrevSourceUser,
        PreviousBalanceSource.previousStatement => l10n.reportingPrevSourcePdf,
        null => null,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final source = _source(l10n);
    return Column(
      key: const Key('reward-derivation-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l10n.reportingResultTitle, caption: true),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RewardDerivation(
                  unit: unit,
                  currency: currency,
                  current: reporting.currentBalance,
                  previous: reporting.previousBalance,
                  redeemed: reporting.redeemedInPeriod,
                  expired: reporting.expiredInPeriod,
                  earned: reporting.earned,
                ),
                if (source != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${l10n.reportingPreviousLabel}: $source',
                    key: const Key('derivation-source'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
