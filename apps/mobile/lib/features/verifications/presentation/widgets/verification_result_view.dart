import 'package:animate_do/animate_do.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../shared/widgets/molecules/inline_message.dart';
import '../../../../shared/widgets/atoms/staggered_entrance.dart';
import '../../../../core/utils/decimal_utils.dart';
import '../../../cards/domain/card_entities.dart';
import '../../domain/verification_entities.dart';
import '../excluded_reason_text.dart';
import '../format_reward.dart';
import '../result_controller.dart' show TransactionFilter;
import 'applied_rates_card.dart';
import 'breakdown_section.dart';
import 'currency_subtotals.dart';
import 'explanation_card.dart';
import 'loyalty_table.dart';
import 'transactions_section.dart';
import 'verdict_card.dart';

/// Pure presentational verification result.
class VerificationResultView extends StatelessWidget {
  const VerificationResultView({
    super.key,
    required this.verification,
    required this.filter,
    required this.onFilterChanged,
    required this.assigned,
    required this.onAssign,
    this.onCorrect,
    this.onRecalculate,
    this.stale = false,
    this.recalculating = false,
    this.onRetryRecalculation,
  });

  final Verification verification;
  final TransactionFilter filter;
  final ValueChanged<TransactionFilter> onFilterChanged;
  final Map<int, String> assigned;
  final ValueChanged<VerificationTransaction> onAssign;

  /// Tap on a line to change its category.
  final ValueChanged<VerificationTransaction>? onCorrect;

  /// Reopens the rate confirmation ("Recalcular con otros %").
  final VoidCallback? onRecalculate;

  /// A correction was saved but the recalculation failed.
  final bool stale;
  final bool recalculating;
  final VoidCallback? onRetryRecalculation;

  @override
  Widget build(BuildContext context) {
    final v = verification;
    final currency = v.currency;
    final verdict = v.verdict;
    final reported = v.reported;
    if (!v.isCompleted || verdict == null || reported == null) {
      return const Center(child: Text(S.resultNotConfirmed));
    }
    // Reported / expected / difference are in the reward currency, which can
    // differ from the card currency; breakdown and lines stay in the card's.
    final rewardCurrency = v.resolvedRewardCurrency;
    String reward(Decimal d) =>
        formatReward(d, v.unit, currency: rewardCurrency);
    final inPrimary = v.expectedInPrimaryCurrency;
    final equivalent =
        v.rewardCurrencyDiffers &&
            inPrimary != null &&
            v.unit != RewardUnit.points
        ? S.equivalentTo(formatMoney(inPrimary, currency: currency))
        : null;
    final diff = v.difference ?? Decimal.zero;
    final hint = switch (verdict) {
      Verdict.match => S.verdictMatchHint,
      Verdict.underpaid => S.verdictUnderpaidHint(reward(-diff)),
      Verdict.overpaid => S.verdictOverpaidHint(reward(diff)),
    };
    final signed = reward(diff);
    final warnings = [
      for (final w in v.warnings)
        if (warningText(w) != null) (w, warningText(w)!),
    ];
    // Sections slide in one after the other under the verdict reveal.
    var section = 2;
    Widget enter(Widget child) =>
        StaggeredEntrance(index: section++, child: child);
    final showCurrencies =
        v.currencies.length > 1 || v.currencies.any((c) => c.excludedCount > 0);
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            VerdictCard(
              verdict: verdict,
              hint: hint,
              expected: reward(v.expectedAmount ?? Decimal.zero),
              reported: reward(reported.amount),
              reportedLabel: reported.label,
              expectedNote: equivalent,
              difference: diff > Decimal.zero ? '+$signed' : signed,
              reportedNote: reported.fromOverride
                  ? S.reportedOverrideNote
                  : null,
              heroTag: 'verdict-${v.id}',
            ),
            if (stale) ...[
              const SizedBox(height: 16),
              InlineMessage(
                key: const Key('stale-banner'),
                message: S.recalcFailedAfterChange,
                tone: InlineMessageTone.warning,
                actionLabel: S.recalcAction,
                onAction: onRetryRecalculation,
              ),
            ],
            if (v.explanation != null) ...[
              const SizedBox(height: 16),
              FadeInUp(
                from: 12,
                delay: const Duration(milliseconds: 600),
                child: ExplanationCard(text: v.explanation!),
              ),
            ],
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (final (w, text) in warnings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InlineMessage(
                    key: Key('warning-${w.code}'),
                    message: text,
                    tone: InlineMessageTone.warning,
                    actionLabel: w.code == 'NO_EXCHANGE_RATE'
                        ? S.recalcAction
                        : null,
                    onAction: w.code == 'NO_EXCHANGE_RATE'
                        ? onRecalculate
                        : null,
                  ),
                ),
            ],
            if (v.appliedRates != null) ...[
              const SizedBox(height: 24),
              enter(
                AppliedRatesCard(
                  applied: v.appliedRates!,
                  onRecalculate: onRecalculate,
                ),
              ),
            ] else if (onRecalculate != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('recalculate-button'),
                onPressed: onRecalculate,
                icon: const Icon(Icons.percent_rounded),
                label: const Text(S.recalcWithOtherRates),
              ),
            ],
            if (v.loyalty.programs.isNotEmpty) ...[
              const SizedBox(height: 24),
              enter(
                LoyaltyTable(
                  loyalty: v.loyalty,
                  currency: rewardCurrency,
                  cumulativeWarning: v.hasWarning(
                    'REPORTED_VALUE_MAY_BE_CUMULATIVE',
                  ),
                ),
              ),
            ],
            if (showCurrencies) ...[
              const SizedBox(height: 24),
              enter(
                CurrencySubtotals(
                  subtotals: v.currencies,
                  primaryCurrency: currency,
                  unit: v.unit,
                ),
              ),
            ],
            const SizedBox(height: 24),
            enter(
              BreakdownSection(
                lines: v.breakdown,
                currency: currency,
                unit: v.unit,
              ),
            ),
            const SizedBox(height: 24),
            TransactionsSection(
              transactions: v.transactions,
              filter: filter,
              onFilterChanged: onFilterChanged,
              currency: currency,
              unit: v.unit,
              assigned: assigned,
              onAssign: onAssign,
              onCorrect: onCorrect,
            ),
          ],
        ),
        if (recalculating)
          Positioned.fill(
            child: ColoredBox(
              key: const Key('recalculating-overlay'),
              color: Theme.of(context).colorScheme.surface
                  .withValues(alpha: 0.6),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}
