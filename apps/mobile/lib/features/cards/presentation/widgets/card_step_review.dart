import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/card_entities.dart';
import '../card_review_data.dart';
import 'card_step_scaffold.dart';

/// Step 4: a summary of everything entered, one section per step with an
/// "Edit" link that jumps back to it, the save error and, when editing, the
/// delete action. Presentational.
class CardStepReview extends StatelessWidget {
  const CardStepReview({
    super.key,
    required this.data,
    required this.onEditStep,
    this.errorMessage,
    this.onDelete,
    this.deleting = false,
  });

  final CardReviewData data;
  final ValueChanged<int> onEditStep;
  final String? errorMessage;

  /// Only when editing an existing card.
  final VoidCallback? onDelete;
  final bool deleting;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final d = data;
    final isPoints = d.unit == RewardUnit.points;
    final reporting = switch (d.reporting) {
      RewardReporting.auto => l10n.cardReportingAuto,
      RewardReporting.monthly => l10n.cardReportingMonthly,
      RewardReporting.cumulative => l10n.cardReportingCumulative,
    };
    return CardStepBody(
      title: l10n.cardStepTitleReview,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: CreditCardView(
              alias: d.alias,
              last4: d.last4,
              currency: d.currency,
              subtitle: d.bank,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        _Section(
          index: 0,
          title: l10n.cardStepTabCard,
          onEdit: () => onEditStep(0),
          rows: [
            (l10n.cardNameLabel, d.alias),
            (l10n.cardBank, d.bank),
            (l10n.cardLast4Short, d.last4),
            (l10n.cardMainCurrency, d.currency),
            if (d.network != null) (l10n.cardNetworkLabel, d.network!),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _Section(
          index: 1,
          title: l10n.cardStepTabReward,
          onEdit: () => onEditStep(1),
          rows: [
            (
              l10n.cardRewardKindQuestion,
              isPoints ? l10n.cardUnitPoints : l10n.cardUnitCashback,
            ),
            if (isPoints && d.pointsFactor != null)
              (l10n.pointsPerUnit, d.pointsFactor!),
            if (!isPoints)
              (
                l10n.cardRewardCurrencyQuestion,
                d.rewardCurrency ?? l10n.cardRewardDetect,
              ),
            (l10n.cardReportingLabel, reporting),
            (
              isPoints
                  ? l10n.cardRewardCapLabelPoints
                  : l10n.cardRewardCapLabel,
              d.cap == null ? l10n.cardRewardCapNone : '${d.cap} ${d.capUnit}',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _Section(
          index: 2,
          title: l10n.cardStepTabRules,
          onEdit: () => onEditStep(2),
          rows: [
            (l10n.cardBaseRateLabel, '${d.baseRate}%'),
            for (final r in d.rules)
              (
                r.name,
                r.cap == null
                    ? '${r.rate}%'
                    : '${r.rate}% · ${l10n.capOf('${r.cap} ${d.capUnit}')}',
              ),
          ],
          footnote: d.rules.isEmpty ? l10n.cardReviewNoRules : null,
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: AppSpacing.lg),
          InlineNotice(message: errorMessage!),
        ],
        if (onDelete != null) ...[
          const SizedBox(height: 18),
          Divider(color: scheme.outlineVariant, height: 1),
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('delete-card'),
            onPressed: deleting ? null : onDelete,
            style: TextButton.styleFrom(
              foregroundColor: scheme.error,
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: Text(l10n.cardDeleteAction),
          ),
          Text(
            l10n.cardDeleteNote,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.index,
    required this.title,
    required this.onEdit,
    required this.rows,
    this.footnote,
  });

  final int index;
  final String title;
  final VoidCallback onEdit;
  final List<(String, String)> rows;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: title,
          caption: true,
          trailing: TextButton(
            key: Key('review-edit-$index'),
            onPressed: onEdit,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 40),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(l10n.edit),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                for (final (label, value) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
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
                    ),
                  ),
                if (footnote != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 6),
                    child: Text(
                      footnote!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
