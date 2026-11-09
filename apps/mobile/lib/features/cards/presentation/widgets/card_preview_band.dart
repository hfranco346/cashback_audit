import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';

/// Compact credit-card band at the top of the card form: alias in Bodoni and
/// `•••• last4`, both following the text controllers live. Presentational.
class CardPreviewBand extends StatelessWidget {
  const CardPreviewBand({super.key, required this.alias, required this.last4});

  final TextEditingController alias;
  final TextEditingController last4;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: Listenable.merge([alias, last4]),
      builder: (context, _) {
        final name = alias.text.trim();
        final digits = last4.text.trim();
        return Semantics(
          container: true,
          label: '${name.isEmpty ? context.l10n.newCard : name} •••• $digits',
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.creditCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFCDAE6E).withValues(alpha: 0.45),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name.isEmpty ? context.l10n.cardAliasHint : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleLarge?.copyWith(
                          fontFamily: AppFonts.display,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: colors.onCreditCard.withValues(
                            alpha: name.isEmpty ? 0.6 : 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      '•••• ${digits.padRight(4, '·')}',
                      style: text.labelLarge?.copyWith(
                        fontSize: 14,
                        letterSpacing: 2.5,
                        color: colors.onCreditCard,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
