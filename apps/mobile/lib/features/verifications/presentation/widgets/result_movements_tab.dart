import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/decimal_utils.dart';
import '../../domain/verification_entities.dart';
import '../format_reward.dart';
import '../result_controller.dart' show TransactionFilter, displayMerchantName;

/// Short Spanish/English reason why a line earns nothing (lowercase, to
/// follow "Excluded · ").
String movementReason(AppLocalizations l10n, VerificationTransaction tx) {
  if (tx.excludedReason == ExcludedReason.noExchangeRate) {
    return l10n.movReasonNoRate(tx.currency);
  }
  return switch (tx.kind) {
    TransactionKind.payment => l10n.movReasonPayment,
    TransactionKind.fee => l10n.movReasonFee,
    TransactionKind.interest => l10n.movReasonInterest,
    TransactionKind.insurance => l10n.movReasonInsurance,
    _ => l10n.movReasonOther,
  };
}

/// "Transactions" tab: the 4-option filter with counters and the lines as
/// green (counted), red (no category) or grey (excluded) rows.
class ResultMovementsTab extends StatelessWidget {
  const ResultMovementsTab({
    super.key,
    required this.verification,
    required this.filter,
    required this.onFilterChanged,
    this.onChangeCategory,
  });

  final Verification verification;
  final TransactionFilter filter;
  final ValueChanged<TransactionFilter> onFilterChanged;

  /// Opens the "Change category" sheet for a line.
  final ValueChanged<VerificationTransaction>? onChangeCategory;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final v = verification;
    final all = v.transactions;
    final counted = all.where((t) => t.inCategory).toList();
    final uncounted = all.where((t) => t.outOfCategory).toList();
    final excluded = all.where((t) => t.isExcluded).toList();
    final visible = switch (filter) {
      TransactionFilter.all => all,
      TransactionFilter.counted => counted,
      TransactionFilter.uncounted => uncounted,
      TransactionFilter.excluded => excluded,
    };
    final options = [
      FilterOption(
        key: const Key('filter-all'),
        value: TransactionFilter.all,
        label: l10n.filterAll,
        count: all.length,
      ),
      FilterOption(
        key: const Key('filter-counted'),
        value: TransactionFilter.counted,
        label: l10n.filterCounted,
        count: counted.length,
      ),
      FilterOption(
        key: const Key('filter-uncounted'),
        value: TransactionFilter.uncounted,
        label: l10n.filterUncounted,
        count: uncounted.length,
      ),
      FilterOption(
        key: const Key('filter-excluded'),
        value: TransactionFilter.excluded,
        label: l10n.filterExcluded,
        count: excluded.length,
      ),
    ];
    return ListView(
      key: const Key('result-movements'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.lg,
        AppSpacing.screen,
        AppSpacing.xxl,
      ),
      children: [
        FilterSegmented<TransactionFilter>(
          options: options,
          selected: filter,
          onChanged: onFilterChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text(l10n.noTransactionsMatch)),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < visible.length; i++)
                  _row(context, visible[i], last: i == visible.length - 1),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text(
            l10n.movementsNote,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    VerificationTransaction tx, {
    required bool last,
  }) {
    final l10n = context.l10n;
    final v = verification;
    final currency = v.currency;
    final txCurrency = tx.currency.isEmpty ? currency : tx.currency;
    final name = tx.matchedMerchantName ?? displayMerchantName(tx.merchant);
    final rate = tx.appliedRatePercent == null
        ? null
        : formatRate(tx.appliedRatePercent!);
    final converted = tx.convertedAmount;
    final extra = <String>[
      if (!tx.isExcluded && converted != null && txCurrency != currency)
        l10n.convertedAs(formatMoney(converted, currency: currency)),
      if (tx.outOfCategory && tx.suggestedHint != null)
        l10n.bankConsiders(tx.suggestedHint!),
      if (tx.creditType != null) _creditType(l10n, tx.creditType!),
      if (!tx.isExcluded && tx.matchReason != null) tx.matchReason!,
    ];
    final StatusKind kind;
    final String status;
    final String? reward;
    if (tx.isExcluded) {
      kind = StatusKind.neutral;
      status = l10n.movExcluded(movementReason(l10n, tx));
      reward = '—';
    } else if (tx.inCategory) {
      kind = StatusKind.ok;
      final who = tx.matchSource.isAi
          ? ' · ${l10n.aiChip}'
          : tx.matchSource == MatchSource.user
          ? ' · ${l10n.userChip}'
          : '';
      status =
          '${l10n.movInCategory(tx.categoryName ?? '', rate ?? '').trim()}$who';
      reward =
          '+${formatReward(tx.expectedReward ?? Decimal.zero, v.unit, currency: currency)}';
    } else {
      kind = StatusKind.error;
      status = l10n.movUncounted(rate ?? '0%');
      reward = formatReward(
        tx.expectedReward ?? Decimal.zero,
        v.unit,
        currency: currency,
      );
    }
    final canChange = !tx.isExcluded && onChangeCategory != null;
    return MovementRow(
      key: Key('tx-${tx.index}'),
      kind: kind,
      name: name,
      bankText: tx.merchant,
      statusText: status,
      amount: formatMoney(tx.signedAmount, currency: txCurrency),
      reward: reward,
      extra: extra,
      showDivider: !last,
      onTap: canChange ? () => onChangeCategory!(tx) : null,
      onAssignCategory: tx.outOfCategory && canChange
          ? () => onChangeCategory!(tx)
          : null,
      assignKey: Key('assign-${tx.index}'),
    );
  }

  static String _creditType(AppLocalizations l10n, CreditType type) =>
      switch (type) {
        CreditType.payment => l10n.creditPayment,
        CreditType.refund => l10n.creditRefund,
        CreditType.otherCredit => l10n.creditOther,
      };
}
