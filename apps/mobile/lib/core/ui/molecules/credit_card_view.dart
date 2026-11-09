import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Credit card (`.cc`): dark green surface, inner brass hairline, alias in
/// Bodoni, `•••• last4` and the reward currency at the top right.
class CreditCardView extends StatelessWidget {
  const CreditCardView({
    super.key,
    required this.alias,
    required this.last4,
    required this.currency,
    this.rewardLabel,
    this.subtitle,
    this.onTap,
  });

  final String alias;
  final String last4;
  final String currency;

  /// Short caps label before the currency, e.g. `CASHBACK`.
  final String? rewardLabel;

  /// Small line under the digits, e.g. `BAC Credomatic · base 0% · 2 rules`.
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final top = rewardLabel == null ? currency : '$rewardLabel · $currency';
    return Semantics(
      container: true,
      label: '$alias •••• $last4 $currency',
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 280 / 172,
          child: Material(
            color: colors.creditCard,
            borderRadius: BorderRadius.circular(AppRadii.creditCard),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                children: [
                  // Inner brass hairline (inset 1px, 45% opacity).
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            AppRadii.creditCard,
                          ),
                          border: Border.all(
                            color: const Color(0xFFCDAE6E)
                                .withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                alias,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.headlineSmall?.copyWith(
                                  color: colors.onCreditCard,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              top,
                              style: text.labelSmall?.copyWith(
                                color: const Color(0xFFCDAE6E),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '•••• $last4',
                              style: text.titleMedium?.copyWith(
                                color: colors.onCreditCard,
                                fontSize: 16,
                                letterSpacing: 2.9,
                                fontFeatures: appFigures,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall?.copyWith(
                                  color: colors.onCreditCard.withValues(
                                    alpha: 0.8,
                                  ),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
