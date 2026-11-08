import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/subscription_entities.dart';

/// Pure presentational subscription summary for the settings screen.
class SubscriptionStatusCard extends StatelessWidget {
  const SubscriptionStatusCard({
    super.key,
    required this.status,
    required this.loading,
    required this.onManage,
  });

  final SubscriptionStatus? status;
  final bool loading;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.statusColors;
    final s = status;
    final date = s?.expiresAt == null
        ? null
        : DateFormat.yMMMd('es_MX').format(s!.expiresAt!.toLocal());
    final (label, color, icon) = switch (s?.state) {
      SubscriptionState.active => (
        S.subscriptionActive,
        colors.success,
        Icons.verified_rounded,
      ),
      SubscriptionState.cancelled => (
        S.subscriptionCancelled,
        theme.colorScheme.onSurfaceVariant,
        Icons.event_busy_rounded,
      ),
      SubscriptionState.billingIssue => (
        S.subscriptionBillingIssue,
        colors.danger,
        Icons.credit_card_off_rounded,
      ),
      SubscriptionState.expired => (
        S.subscriptionExpired,
        colors.danger,
        Icons.history_toggle_off_rounded,
      ),
      _ => (
        S.subscriptionNone,
        theme.colorScheme.onSurfaceVariant,
        Icons.workspace_premium_outlined,
      ),
    };
    final detail = switch (s?.state) {
      SubscriptionState.active when date != null =>
        s!.willRenew ? S.subscriptionRenews(date) : S.subscriptionEnds(date),
      SubscriptionState.cancelled when date != null => S.subscriptionEnds(date),
      SubscriptionState.billingIssue => S.subscriptionBillingIssueHint,
      _ => null,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        key: const Key('subscription-label'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: color,
                        ),
                      ),
                      if (detail != null)
                        Text(
                          detail,
                          key: const Key('subscription-detail'),
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (!(s?.active ?? false)) ...[
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('manage-subscription'),
                onPressed: onManage,
                child: const Text(S.subscribeNow),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
