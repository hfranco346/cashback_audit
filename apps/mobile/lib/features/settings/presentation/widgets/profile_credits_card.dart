import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../credits/domain/credit_entities.dart';

/// Balance split by bucket (free / plan / purchased) and the way to get more.
class ProfileCreditsCard extends StatelessWidget {
  const ProfileCreditsCard({
    super.key,
    required this.balance,
    required this.onGetMore,
  });

  final CreditBalance? balance;
  final VoidCallback onGetMore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final b = balance;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    l10n.profileChecksAvailable,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  b == null ? '–' : '${b.total}',
                  key: const Key('profile-credits-total'),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    fontFeatures: appFigures,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Bag(
                  keyName: 'free',
                  value: b?.free,
                  label: l10n.profileBagFree,
                ),
                const SizedBox(width: 8),
                _Bag(
                  keyName: 'plan',
                  value: b?.plan,
                  label: l10n.profileBagPlan,
                ),
                const SizedBox(width: 8),
                _Bag(
                  keyName: 'purchased',
                  value: b?.purchased,
                  label: l10n.profileBagPurchased,
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppButton(
              key: const Key('profile-get-more'),
              label: l10n.profileGetMore,
              onPressed: onGetMore,
            ),
          ],
        ),
      ),
    );
  }
}

class _Bag extends StatelessWidget {
  const _Bag({required this.keyName, required this.value, required this.label});

  final String keyName;
  final int? value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            children: [
              Text(
                value == null ? '–' : '$value',
                key: Key('bag-$keyName'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: appFigures,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
