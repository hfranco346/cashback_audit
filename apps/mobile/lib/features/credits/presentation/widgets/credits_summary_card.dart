import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/strings.dart';
import '../../domain/credit_entities.dart';
import 'credits_chip.dart';

/// Balance by bucket plus the actions to buy more or see the ledger
/// (settings screen).
class CreditsSummaryCard extends StatelessWidget {
  const CreditsSummaryCard({
    super.key,
    required this.balance,
    required this.loading,
    required this.onBuy,
    required this.onHistory,
  });

  final CreditBalance? balance;
  final bool loading;
  final VoidCallback onBuy;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = balance;
    final date = b?.planPeriodEnd == null || b!.plan == 0
        ? null
        : DateFormat.yMMMd('es_MX').format(b.planPeriodEnd!.toLocal());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: CreditsChip(balance: b, onTap: onBuy),
                ),
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (b != null) ...[
              const SizedBox(height: 10),
              Text(
                S.creditsBreakdown(b.free, b.plan, b.purchased),
                key: const Key('credits-breakdown'),
                style: theme.textTheme.bodyMedium,
              ),
              if (date != null)
                Text(
                  S.creditsPlanExpires(date),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonalIcon(
                  key: const Key('credits-buy'),
                  onPressed: onBuy,
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: const Text(S.creditsBuy),
                ),
                TextButton.icon(
                  key: const Key('credits-history'),
                  onPressed: onHistory,
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text(S.creditsHistoryTitle),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
