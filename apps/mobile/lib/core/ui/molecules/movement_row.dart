import 'package:flutter/material.dart';

import '../../l10n/l10n_context.dart';
import '../../theme/app_theme.dart';
import '../atoms/status_pill.dart';

/// Statement line (`.mv`): status dot with icon, clean merchant name in bold,
/// the bank's original text small, colored status, amount + reward on the
/// right and an "Assign category" button on red rows.
class MovementRow extends StatelessWidget {
  const MovementRow({
    super.key,
    required this.kind,
    required this.name,
    required this.statusText,
    required this.amount,
    this.bankText,
    this.reward,
    this.onAssignCategory,
    this.assignLabel,
    this.assignKey,
    this.extra = const [],
    this.onTap,
    this.showDivider = true,
  });

  final StatusKind kind;

  /// Clean merchant name.
  final String name;

  /// Original bank text; never translated.
  final String? bankText;

  /// Status in words, e.g. `In category · Groceries 7%`.
  final String statusText;

  /// Amount with ISO code, already formatted.
  final String amount;

  /// Reward, already formatted with sign (e.g. `+HNL 79.84`).
  final String? reward;

  /// Shows the "Assign category" button when set (meant for red rows).
  final VoidCallback? onAssignCategory;
  final String? assignLabel;
  final Key? assignKey;

  /// Muted lines under the status (converted amount, bank hint...).
  final List<String> extra;

  /// Tap on the whole row (e.g. change its category).
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = kind.tone(context.appColors);
    final muted = theme.colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant),
              )
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusDot(kind: kind, semanticLabel: statusText),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (bankText != null)
                          Text(
                            bankText!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                              fontSize: 11,
                            ),
                          ),
                        Text(
                          statusText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tone.fg,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        for (final line in extra)
                          Text(
                            line,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        amount,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontFeatures: appFigures,
                          color: kind == StatusKind.neutral ? muted : null,
                        ),
                      ),
                      if (reward != null)
                        Text(
                          reward!,
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tone.fg,
                            fontWeight: FontWeight.w700,
                            fontFeatures: appFigures,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (onAssignCategory != null)
                Padding(
                  padding: const EdgeInsets.only(left: 40),
                  child: OutlinedButton(
                    key: assignKey,
                    onPressed: onAssignCategory,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      minimumSize: const Size(48, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: theme.textTheme.labelLarge?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(assignLabel ?? context.l10n.assignCategory),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
