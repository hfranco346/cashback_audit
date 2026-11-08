import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/decimal_utils.dart';
import '../../../cards/domain/card_entities.dart';
import '../../domain/verification_entities.dart';
import '../format_reward.dart';

/// One statement line, marked green (counted in a category) or red (not
/// counted). Color is always paired with an icon and a text label.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.currency,
    required this.unit,
    this.assignedCategory,
    this.onAssign,
  });

  final VerificationTransaction transaction;
  final String currency;
  final RewardUnit unit;

  /// Category the user assigned this line to from the result screen.
  final String? assignedCategory;
  final VoidCallback? onAssign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = context.statusColors;
    final tx = transaction;
    final counted = tx.inCategory;
    final color = counted ? status.success : status.danger;
    final bg = counted ? status.successContainer : status.dangerContainer;
    final label = counted ? S.countedLabel : S.uncountedLabel;
    final amountText = formatMoney(tx.signedAmount, currency: currency);
    final rate = formatRate(tx.appliedRatePercent);

    return MergeSemantics(
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
                Icon(
                  counted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  key: Key(counted ? 'tx-icon-counted' : 'tx-icon-uncounted'),
                  color: color,
                ),
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
                          if (tx.matchSource == MatchSource.ai)
                            Tooltip(
                              message: S.aiChipTooltip,
                              child: Container(
                                key: Key('ai-chip-${tx.index}'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  S.aiChip,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color:
                                        theme.colorScheme.onTertiaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          Text(
                            counted && tx.ruleApplied
                                ? S.appliedRate(rate)
                                : '${S.baseOnly} $rate',
                            key: Key('tx-rate-${tx.index}'),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (tx.isCredit)
                            Text(
                              S.refund,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
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
                    Text(
                      formatReward(tx.expectedReward, unit, currency: currency),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (!counted)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 34),
                child: assignedCategory != null
                    ? Text(
                        S.assignedTo(assignedCategory!),
                        key: Key('tx-assigned-${tx.index}'),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: status.success,
                        ),
                      )
                    : (onAssign == null
                          ? const SizedBox.shrink()
                          : Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                key: Key('assign-${tx.index}'),
                                onPressed: onAssign,
                                icon: const Icon(
                                  Icons.drive_file_move_outline,
                                  size: 18,
                                ),
                                label: const Text(S.assignToCategory),
                                style: TextButton.styleFrom(
                                  foregroundColor: color,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            )),
              ),
          ],
        ),
      ),
    );
  }
}
