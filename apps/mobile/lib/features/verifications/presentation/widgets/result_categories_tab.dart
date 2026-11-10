import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/decimal_utils.dart';
import '../../../../core/utils/rate_direction.dart';
import '../../../cards/domain/card_entities.dart';
import '../../domain/verification_entities.dart';
import '../format_reward.dart';
import 'result_summary_tab.dart'
    show CapAppliedCard, KvCard, KvRow, LoyaltyCard;
import 'reward_derivation.dart';

/// "Categories" tab: the percentages the audit used (and the reward
/// conversion), the per-currency subtotals of a multi-currency statement
/// and every rewards program printed on the statement.
class ResultCategoriesTab extends StatelessWidget {
  const ResultCategoriesTab({
    super.key,
    required this.verification,
    this.onRecalculate,
  });

  final Verification verification;
  final VoidCallback? onRecalculate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final v = verification;
    final applied = v.appliedRates;
    final currency = v.currency;
    final showCurrencies =
        v.currencies.length > 1 || v.currencies.any((c) => c.excludedCount > 0);
    final muted = theme.colorScheme.onSurfaceVariant;
    return ListView(
      key: const Key('result-categories'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.lg,
        AppSpacing.screen,
        AppSpacing.xxl,
      ),
      children: [
        if (applied != null) ...[
          SectionHeader(title: l10n.resultRatesUsed, caption: true),
          const SizedBox(height: 8),
          KeyedSubtree(
            key: const Key('applied-rates-card'),
            child: KvCard(
              children: [
                KvRow(
                  label: l10n.rateBaseTitle,
                  value: formatRate(applied.baseRatePercent),
                ),
                for (final r in applied.categoryRates)
                  KvRow(
                    label: r.categoryName ?? '',
                    value: r.monthlyCap == null
                        ? formatRate(r.ratePercent)
                        : '${formatRate(r.ratePercent)} · ${l10n.capOf(formatReward(r.monthlyCap!, v.unit, currency: currency))}',
                  ),
                if (v.rewardCapApplied case final capApplied?)
                  KvRow(
                    key: const Key('applied-cap-row'),
                    label: l10n.resultCapRow,
                    value:
                        '${formatReward(capApplied.uncapped, v.unit, currency: currency)} → ${formatReward(capApplied.capped, v.unit, currency: currency)}',
                  ),
                if (applied.rewardExchangeRate != null)
                  _RewardRate(rate: applied.rewardExchangeRate!),
              ],
            ),
          ),
        ],
        if (applied == null && v.rewardCapApplied != null) ...[
          CapAppliedCard(
            cap: v.rewardCapApplied!,
            format: (d) => formatReward(d, v.unit, currency: currency),
          ),
        ],
        if (showCurrencies) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: l10n.resultCurrencies, caption: true),
          const SizedBox(height: 8),
          KvCard(
            children: [
              for (final s in v.currencies)
                _CurrencyRow(
                  subtotal: s,
                  primaryCurrency: currency,
                  unit: v.unit,
                ),
            ],
          ),
        ],
        if (v.loyalty.programs.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: l10n.loyaltyTitle, caption: true),
          const SizedBox(height: 8),
          LoyaltyCard(
            loyalty: v.loyalty,
            currency: v.resolvedRewardCurrency,
            cumulativeWarning: v.hasWarning('REPORTED_VALUE_MAY_BE_CUMULATIVE'),
          ),
        ],
        if (v.rewardReporting case final r? when r.isCumulative) ...[
          const SizedBox(height: AppSpacing.md),
          RewardDerivationSection(
            reporting: r,
            unit: v.unit,
            currency: v.resolvedRewardCurrency,
          ),
        ],
        if (applied == null &&
            !showCurrencies &&
            v.loyalty.programs.isEmpty &&
            !(v.rewardReporting?.isCumulative ?? false))
          Text(
            l10n.noTransactionsMatch,
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
        if (onRecalculate != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton.ghost(label: l10n.recalcFree, onPressed: onRecalculate),
        ],
      ],
    );
  }
}

class _RewardRate extends StatelessWidget {
  const _RewardRate({required this.rate});

  final AppliedRewardRate rate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    // Same direction as the question that was asked: stronger currency first.
    final direction = RateDirection.choose(
      primary: rate.fromCurrency,
      other: rate.toCurrency,
      knownStored: rate.rate,
    );
    final origin = switch (rate.source) {
      'STATEMENT_CONFIRMED' => l10n.rewardRateFromStatement,
      'USER_ENTERED' => l10n.rewardRateUserEntered,
      _ => null,
    };
    return Column(
      key: const Key('reward-rate-detail'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KvRow(
          label: l10n.rewardRateDetailTitle,
          value: l10n.rewardRateDetail(
            direction.unit,
            formatExchangeRate(direction.toShown(rate.rate)),
            direction.quote,
          ),
        ),
        if (origin != null)
          Text(
            origin,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({
    required this.subtotal,
    required this.primaryCurrency,
    required this.unit,
  });

  final CurrencySubtotal subtotal;
  final String primaryCurrency;
  final RewardUnit unit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.appColors;
    final s = subtotal;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: appFigures,
    );
    return Column(
      key: Key('currency-${s.currency}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              s.currency,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            if (s.expectedReward != null)
              Text(
                formatReward(
                  s.expectedReward!,
                  unit,
                  currency: primaryCurrency,
                ),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: appFigures,
                ),
              ),
          ],
        ),
        Text(
          '${l10n.currencySpent}: ${formatMoney(s.spent, currency: s.currency)}',
          style: muted,
        ),
        if (!s.isPrimary && s.exchangeRate != null)
          Text(
            l10n.currencyRate(
              s.currency,
              primaryCurrency,
              decimalToApi(s.exchangeRate!),
            ),
            style: muted,
          ),
        if (s.excludedCount > 0)
          Row(
            key: Key('currency-excluded-${s.currency}'),
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: colors.error.fg,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  l10n.currencyExcluded(s.excludedCount),
                  style: muted?.copyWith(color: colors.error.fg),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
