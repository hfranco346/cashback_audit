import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/credit_entities.dart';

/// "N verificaciones disponibles" chip. Tapping it opens the paywall.
class CreditsChip extends StatelessWidget {
  const CreditsChip({super.key, required this.balance, required this.onTap});

  /// `null` while the balance is not known yet.
  final CreditBalance? balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = balance;
    if (b == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final status = context.statusColors;
    final has = b.hasCredits;
    final fg = has ? status.success : status.danger;
    final bg = has ? status.successContainer : status.dangerContainer;
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        child: InkWell(
          key: const Key('credits-chip'),
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, size: 18, color: fg),
                const SizedBox(width: 6),
                Text(
                  has ? S.creditsAvailable(b.total) : S.creditsNone,
                  key: const Key('credits-chip-label'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
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
