import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/decimal_utils.dart';
import '../../../cards/domain/card_entities.dart';
import '../../domain/verification_entities.dart';
import '../excluded_reason_text.dart';
import '../format_reward.dart';

/// One statement line in one of three looks:
///  - green: counted in one of the user's categories,
///  - red: a purchase that is not in any category,
///  - grey: excluded (payments, fees, interest, insurance, foreign lines
///    without a rate): neither a hit nor a miss.
/// Color is always paired with an icon and a text label.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.currency,
    required this.unit,
    this.assignedCategory,
    this.onAssign,
    this.onTap,
  });

  final VerificationTransaction transaction;

  /// Primary currency (rewards are expressed in it).
  final String currency;
  final RewardUnit unit;

  /// Category the user assigned this line to for future statements.
  final String? assignedCategory;
  final VoidCallback? onAssign;

  /// Tap to change the line's category (not offered for excluded lines).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = context.statusColors;
    final tx = transaction;
    final excluded = tx.isExcluded;
    final counted = tx.inCategory;
    final (color, bg, label, icon, iconKey) = excluded
        ? (
            status.neutral,
            status.neutralContainer,
            S.excludedLabel,
            Icons.remove_circle_outline_rounded,
            'tx-icon-excluded',
          )
        : counted
        ? (
            status.success,
            status.successContainer,
            S.countedLabel,
            Icons.check_circle_rounded,
            'tx-icon-counted',
          )
        : (
            status.danger,
            status.dangerContainer,
            S.uncountedLabel,
            Icons.cancel_rounded,
            'tx-icon-uncounted',
          );
    final txCurrency = tx.currency.isEmpty ? currency : tx.currency;
    final amountText = formatMoney(tx.signedAmount, currency: txCurrency);
    final converted = tx.convertedAmount;
    final showConverted =
        !excluded && converted != null && txCurrency != currency;
    final rate = tx.appliedRatePercent == null
        ? null
        : formatRate(tx.appliedRatePercent!);
    final reason = excludedReasonText(tx);

    return MergeSemantics(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('tx-tap-${tx.index}'),
          borderRadius: BorderRadius.circular(14),
          onTap: excluded ? null : onTap,
          child: Container(
            key: Key('tx-${tx.index}'),
            decoration: BoxDecoration(
              color: bg.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border(left: BorderSide(color: color, width: 4)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, key: Key(iconKey), color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.merchant,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                label,
                                key: Key('tx-label-${tx.index}'),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (counted && tx.categoryName != null)
                                Text(
                                  tx.categoryName!,
                                  style: theme.textTheme.labelMedium,
                                ),
                              if (tx.matchSource.isAi && !excluded)
                                _Chip(
                                  key: Key('ai-chip-${tx.index}'),
                                  text: S.aiChip,
                                  tooltip: S.aiChipTooltip,
                                ),
                              if (tx.matchSource == MatchSource.user &&
                                  !excluded)
                                _Chip(
                                  key: Key('user-chip-${tx.index}'),
                                  text: S.userChip,
                                  tooltip: S.userChipTooltip,
                                ),
                              if (!excluded && rate != null)
                                Text(
                                  counted && tx.ruleApplied
                                      ? S.appliedRate(rate)
                                      : '${S.baseOnly} $rate',
                                  key: Key('tx-rate-${tx.index}'),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              if (tx.creditType != null)
                                Text(
                                  creditTypeLabel(tx.creditType!),
                                  key: Key('tx-credit-${tx.index}'),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          if (tx.outOfCategory && tx.suggestedHint != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline_rounded,
                                    size: 14,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      S.bankConsiders(tx.suggestedHint!),
                                      key: Key('tx-hint-${tx.index}'),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (excluded && reason != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                reason,
                                key: Key('tx-excluded-reason-${tx.index}'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          if (!excluded && tx.matchReason != null)
                            Tooltip(
                              message: tx.matchReason!,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  tx.matchReason!,
                                  key: Key('tx-reason-${tx.index}'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          amountText,
                          key: Key('tx-amount-${tx.index}'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (showConverted)
                          Text(
                            S.convertedAs(
                              formatMoney(converted, currency: currency),
                            ),
                            key: Key('tx-converted-${tx.index}'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        if (!excluded && tx.expectedReward != null)
                          Text(
                            formatReward(
                              tx.expectedReward ?? Decimal.zero,
                              unit,
                              currency: currency,
                            ),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (tx.outOfCategory && assignedCategory != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 34),
                    child: Text(
                      S.assignedTo(assignedCategory!),
                      key: Key('tx-assigned-${tx.index}'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: status.success,
                      ),
                    ),
                  )
                else if (tx.outOfCategory && onAssign != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 34),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: Key('assign-${tx.index}'),
                        onPressed: onAssign,
                        icon: const Icon(
                          Icons.drive_file_move_outline,
                          size: 18,
                        ),
                        label: Text(S.assignToCategory),
                        style: TextButton.styleFrom(
                          foregroundColor: color,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Spanish label of a credit line. A payment is never called a refund.
String creditTypeLabel(CreditType type) => switch (type) {
  CreditType.payment => S.creditPayment,
  CreditType.refund => S.creditRefund,
  CreditType.otherCredit => S.creditOther,
};

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.text, required this.tooltip});

  final String text;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onTertiaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
