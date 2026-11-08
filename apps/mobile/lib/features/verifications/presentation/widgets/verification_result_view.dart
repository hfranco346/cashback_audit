import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/utils/decimal_utils.dart';
import '../../../../shared/widgets/molecules/inline_message.dart';
import '../../domain/verification_entities.dart';
import '../format_reward.dart';
import '../result_controller.dart' show TransactionFilter;
import 'breakdown_section.dart';
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
  });

  final Verification verification;
  final TransactionFilter filter;
  final ValueChanged<TransactionFilter> onFilterChanged;
  final Map<int, String> assigned;
  final ValueChanged<VerificationTransaction> onAssign;

  @override
  Widget build(BuildContext context) {
    final v = verification;
    final currency = v.statement.currency ?? 'MXN';
    String reward(d) => formatReward(d, v.unit, currency: currency);
    final diff = v.difference;
    final hint = switch (v.verdict) {
      Verdict.match => S.verdictMatchHint,
      Verdict.underpaid => S.verdictUnderpaidHint(reward(-diff)),
      Verdict.overpaid => S.verdictOverpaidHint(reward(diff)),
    };
    final signed = reward(diff);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        VerdictCard(
          verdict: v.verdict,
          hint: hint,
          expected: reward(v.expectedAmount),
          reported: reward(v.reported.amount),
          difference: diff > parseDecimal(0) ? '+$signed' : signed,
          reportedNote: v.reported.fromOverride ? S.reportedOverrideNote : null,
          heroTag: 'verdict-${v.id}',
        ),
        if (v.warnings.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final w in v.warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InlineMessage(
                message: w.message,
                tone: InlineMessageTone.warning,
              ),
            ),
        ],
        const SizedBox(height: 24),
        BreakdownSection(lines: v.breakdown, currency: currency, unit: v.unit),
        const SizedBox(height: 24),
        TransactionsSection(
          transactions: v.transactions,
          filter: filter,
          onFilterChanged: onFilterChanged,
          currency: currency,
          unit: v.unit,
          assigned: assigned,
          onAssign: onAssign,
        ),
      ],
    );
  }
}
