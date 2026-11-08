import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/utils/decimal_utils.dart';
import '../../domain/card_entities.dart';

/// Presentational card summary styled like a physical card.
class CardTile extends StatelessWidget {
  const CardTile({
    super.key,
    required this.card,
    required this.onTap,
    this.onLongPress,
    this.compact = false,
  });

  final CreditCard card;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = scheme.onPrimary;
    return Hero(
      tag: 'card-${card.id}',
      flightShuttleBuilder: (_, _, _, _, toContext) =>
          Material(type: MaterialType.transparency, child: toContext.widget),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary,
                Color.lerp(scheme.primary, Colors.black, 0.35)!,
              ],
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          card.alias,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: fg,
                          ),
                        ),
                      ),
                      Icon(
                        card.isPoints
                            ? Icons.stars_rounded
                            : Icons.savings_rounded,
                        color: fg.withValues(alpha: 0.85),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${card.bank}${card.network == null ? '' : ' · ${card.network}'}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: fg.withValues(alpha: 0.8),
                    ),
                  ),
                  SizedBox(height: compact ? 12 : 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '•••• ${card.last4}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: fg,
                          letterSpacing: 2,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const Spacer(),
                      _Pill(
                        label: S.baseRateShort(
                          formatRate(card.baseRatePercent),
                        ),
                        color: fg,
                      ),
                      const SizedBox(width: 6),
                      _Pill(label: S.ruleCount(card.rules.length), color: fg),
                    ],
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

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}
