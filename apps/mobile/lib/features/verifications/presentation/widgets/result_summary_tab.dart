import 'package:animate_do/animate_do.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/decimal_utils.dart';
import '../../../cards/domain/card_entities.dart';
import '../../domain/verification_entities.dart';
import '../warning_text.dart';
import '../format_reward.dart';
import 'reward_derivation.dart';

/// Rows of a card separated by hairlines (`.card` + `.kv`).
class KvCard extends StatelessWidget {
  const KvCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final line = Theme.of(context).colorScheme.outlineVariant;
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                border: i == children.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: line)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: children[i],
              ),
            ),
        ],
      ),
    );
  }
}

/// Label on the left, value on the right.
class KvRow extends StatelessWidget {
  const KvRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: appFigures,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Card cap reached": the card-wide cap per statement cut the total, shown
/// as `uncapped → capped`. Amounts are in the card's currency.
class CapAppliedCard extends StatelessWidget {
  const CapAppliedCard({super.key, required this.cap, required this.format});

  final RewardCapApplied cap;
  final String Function(Decimal) format;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Container(
      key: const Key('cap-applied'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.warning.bg,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.warning.fg.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.vertical_align_top_rounded,
                size: 18,
                color: colors.warning.fg,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.resultCapTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.warning.fg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.resultCapChange(format(cap.uncapped), format(cap.capped)),
            key: const Key('cap-applied-change'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: appFigures,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.resultCapBody(format(cap.cap)),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Summary" tab: the verdict, a short explanation, one collapsible notice,
/// the breakdown by category and the audited rewards program.
class ResultSummaryTab extends StatelessWidget {
  const ResultSummaryTab({
    super.key,
    required this.verification,
    this.onRecalculate,
    this.onClaim,
    this.onReviewProgram,
  });

  final Verification verification;
  final VoidCallback? onRecalculate;

  /// "Claim from your bank": only shown when the verdict is underpaid.
  final VoidCallback? onClaim;
  final VoidCallback? onReviewProgram;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.appColors;
    final v = verification;
    final currency = v.currency;
    final rewardCurrency = v.resolvedRewardCurrency;
    String reward(Decimal d) =>
        formatReward(d, v.unit, currency: rewardCurrency);
    final verdict = v.verdict!;
    final reported = v.reported!;
    final diff = v.difference ?? Decimal.zero;

    final (kind, pill, title, icon) = switch (verdict) {
      Verdict.underpaid => (
        StatusKind.error,
        l10n.verdictPillUnderpaid,
        l10n.resultTitleUnderpaid,
        Icons.arrow_downward_rounded,
      ),
      Verdict.overpaid => (
        StatusKind.overpaid,
        l10n.verdictPillOverpaid,
        l10n.resultTitleOverpaid,
        Icons.arrow_upward_rounded,
      ),
      Verdict.match => (
        StatusKind.ok,
        l10n.verdictPillMatch,
        l10n.resultTitleMatch,
        Icons.check_rounded,
      ),
    };
    final amount = switch (verdict) {
      Verdict.underpaid => reward(diff),
      Verdict.overpaid => '+${reward(diff)}',
      Verdict.match => reward(reported.amount),
    };
    final note = switch (verdict) {
      Verdict.underpaid => l10n.resultNoteUnderpaid,
      Verdict.overpaid => l10n.resultNoteOverpaid,
      Verdict.match => l10n.resultNoteMatch(
        reward(diff.abs()),
        reward(v.tolerance ?? Decimal.zero),
      ),
    };
    final rate = v.appliedRates?.rewardExchangeRate;
    final inPrimary = v.expectedInPrimaryCurrency;
    final equivalence =
        v.rewardCurrencyDiffers &&
            inPrimary != null &&
            v.unit != RewardUnit.points
        ? (rate == null
              ? l10n.equivalentTo(formatMoney(inPrimary, currency: currency))
              : l10n.resultEquivalent(
                  formatMoney(inPrimary, currency: currency),
                  rate.toCurrency,
                  decimalToApi(rate.rate),
                  rate.fromCurrency,
                ))
        : null;

    final warnings = [
      for (final w in v.warnings)
        if (warningText(l10n, w) != null) (w, warningText(l10n, w)!),
    ];
    final hasMissingRate = warnings.any((e) => e.$1.code == 'NO_EXCHANGE_RATE');
    final hasCumulative = warnings.any(
      (e) => e.$1.code == 'REPORTED_VALUE_MAY_BE_CUMULATIVE',
    );
    final bullets = (v.explanation ?? '')
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final programs = v.loyalty.programs;
    final derived = v.rewardReporting?.isCumulative ?? false
        ? v.rewardReporting
        : null;

    return ListView(
      key: const Key('result-summary'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.lg,
        AppSpacing.screen,
        AppSpacing.xxl,
      ),
      children: [
        ZoomIn(
          duration: const Duration(milliseconds: 600),
          from: 0.9,
          child: VerdictCard(
            key: const Key('verdict-card'),
            kind: kind,
            statusIcon: icon,
            statusLabel: pill,
            title: title,
            amount: amount,
            amountNote: note,
            expectedLabel: l10n.expectedLabel,
            expected: reward(v.expectedAmount ?? Decimal.zero),
            reportedLabel: reported.fromOverride
                ? '${l10n.reportedByBank} · ${l10n.reportedOverrideNote}'
                : derived != null
                ? '${l10n.reportedByBank} · ${l10n.reportedDerivedNote}'
                : l10n.reportedByBank,
            reported: reward(reported.amount),
            equivalence: equivalence,
          ),
        ),
        if (v.rewardCapApplied case final capApplied?) ...[
          const SizedBox(height: AppSpacing.md),
          CapAppliedCard(
            cap: capApplied,
            format: (d) => formatReward(d, v.unit, currency: currency),
          ),
        ],
        if (derived != null) ...[
          const SizedBox(height: AppSpacing.md),
          RewardDerivationSection(
            reporting: derived,
            unit: v.unit,
            currency: rewardCurrency,
          ),
        ],
        if (verdict == Verdict.underpaid && onClaim != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppButton(
            key: const Key('result-claim'),
            label: l10n.resultClaimCta,
            icon: Icons.mail_outline_rounded,
            onPressed: onClaim,
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              l10n.resultClaimHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        if (bullets.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          FadeInUp(
            from: 12,
            delay: const Duration(milliseconds: 500),
            child: Column(
              key: const Key('explanation-card'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: l10n.explanationTitle, caption: true),
                const SizedBox(height: 8),
                for (final b in bullets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: colors.brass,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            b,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.45,
                              fontFeatures: appFigures,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          CollapsibleWarning(
            key: const Key('result-warnings'),
            title: l10n.noticeCount(warnings.length),
            messages: [for (final e in warnings) e.$2],
            initiallyExpanded: true,
            actionLabel: hasMissingRate && onRecalculate != null
                ? l10n.warnActionAddRate
                : hasCumulative && onReviewProgram != null
                ? l10n.warnActionReviewProgram
                : null,
            onAction: hasMissingRate && onRecalculate != null
                ? onRecalculate
                : onReviewProgram,
          ),
        ],
        if (v.breakdown.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: l10n.resultByCategory, caption: true),
          const SizedBox(height: 8),
          KvCard(
            children: [
              for (final line in v.breakdown)
                _BreakdownRow(line: line, currency: currency, unit: v.unit),
            ],
          ),
        ],
        if (programs.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: l10n.resultProgram, caption: true),
          const SizedBox(height: 8),
          LoyaltyCard(
            loyalty: v.loyalty,
            currency: rewardCurrency,
            cumulativeWarning: hasCumulative,
          ),
        ],
        if (onRecalculate != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton.ghost(
            key: const Key('recalculate-button'),
            label: l10n.recalcFree,
            onPressed: onRecalculate,
          ),
        ],
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.line,
    required this.currency,
    required this.unit,
  });

  final BreakdownLine line;
  final String currency;
  final RewardUnit unit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.appColors;
    final muted = theme.colorScheme.onSurfaceVariant;
    final name = line.isBase
        ? l10n.baseRateLine
        : (line.categoryName ?? l10n.baseRateLine);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$name · ${formatRate(line.ratePercent)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                l10n.breakdownDetail(
                  formatMoney(line.spend, currency: currency),
                  line.transactionCount,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: muted,
                  fontFeatures: appFigures,
                ),
              ),
              if (line.capped && line.monthlyCap != null)
                Text(
                  '${l10n.capped} · ${l10n.capOf(formatReward(line.monthlyCap!, unit, currency: currency))}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.error.fg,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          formatReward(line.expectedReward, unit, currency: currency),
          style: theme.textTheme.titleSmall?.copyWith(
            color: colors.success.fg,
            fontWeight: FontWeight.w800,
            fontFeatures: appFigures,
          ),
        ),
      ],
    );
  }
}

/// Every loyalty program printed on the statement as label/value rows; the
/// audited one is first and marked.
class LoyaltyCard extends StatelessWidget {
  const LoyaltyCard({
    super.key,
    required this.loyalty,
    required this.currency,
    this.cumulativeWarning = false,
  });

  final LoyaltyInfo loyalty;
  final String currency;
  final bool cumulativeWarning;

  String _value(Decimal v, LoyaltyProgram p) => switch (p.unit) {
    'POINTS' => formatPoints(v),
    'CURRENCY' => formatMoney(v, currency: p.currency ?? currency),
    'MILES' => '${formatPoints(v).replaceAll(' pts', '')} mi',
    _ => formatPoints(v).replaceAll(' pts', ''),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selected = loyalty.selectedProgram?.name;
    final programs = [...loyalty.programs]
      ..sort(
        (a, b) => (b.name == selected ? 1 : 0) - (a.name == selected ? 1 : 0),
      );
    final rows = <Widget>[];
    for (final p in programs) {
      final audited = p.name == selected;
      rows.add(
        Wrap(
          key: Key('program-row-${p.name}'),
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              p.name,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (audited)
              StatusPill(
                key: const Key('audited-label'),
                kind: StatusKind.ok,
                label: l10n.loyaltyAudited,
              ),
            if (audited && cumulativeWarning)
              StatusPill(
                key: const Key('cumulative-chip'),
                kind: StatusKind.warning,
                label: l10n.loyaltyCumulativeChip,
              ),
          ],
        ),
      );
      for (final (label, value) in [
        (l10n.loyaltyAccumulated, p.accumulated),
        (l10n.loyaltyAvailable, p.available),
        (l10n.loyaltyRedeemed, p.redeemedInPeriod),
        (l10n.loyaltyExpiring, p.expiring),
        (l10n.loyaltyForfeited, p.forfeited),
      ]) {
        if (value != null) {
          rows.add(KvRow(label: label, value: _value(value, p)));
        }
      }
    }
    return KeyedSubtree(
      key: const Key('loyalty-table'),
      child: KvCard(children: rows),
    );
  }
}
