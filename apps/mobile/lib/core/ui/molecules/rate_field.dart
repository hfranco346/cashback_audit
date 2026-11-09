import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n_context.dart';
import '../../theme/app_theme.dart';
import '../atoms/status_pill.dart';

/// Where a percentage came from; drives the label under the field.
enum RateSource { detected, cardRules, previous, required }

/// Percentage field with a source label: "Detected in your statement" (plus
/// the bank's quote with a brass rule), "From your card rules" or "Required".
class RateField extends StatelessWidget {
  const RateField({
    super.key,
    required this.title,
    required this.source,
    this.subtitle,
    this.controller,
    this.quote,
    this.errorText,
    this.onChanged,
    this.sourceLabel,
  });

  /// Category (or "base rate") name.
  final String title;
  final String? subtitle;
  final RateSource source;
  final TextEditingController? controller;

  /// Literal bank text backing a detected rate; shown as is, not translated.
  final String? quote;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  /// Overrides the localized label of [source].
  final String? sourceLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final colors = context.appColors;
    final muted = theme.colorScheme.onSurfaceVariant;
    final (kind, icon, label) = switch (source) {
      RateSource.detected => (
        StatusKind.ok,
        Icons.description_outlined,
        l10n.badgeStatement,
      ),
      RateSource.cardRules => (
        StatusKind.neutral,
        Icons.credit_card_rounded,
        l10n.badgeCardRule,
      ),
      RateSource.previous => (
        StatusKind.neutral,
        Icons.history_rounded,
        l10n.badgePrevious,
      ),
      RateSource.required => (
        StatusKind.error,
        Icons.error_outline_rounded,
        l10n.badgeRequired,
      ),
    };
    final hasError = errorText != null;
    return Card(
      shape: source == RateSource.required || hasError
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.card),
              side: BorderSide(color: theme.colorScheme.error, width: 2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 96,
                  height: 48,
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    textAlign: TextAlign.end,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: appFigures,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      suffixText: '%',
                      suffixStyle: theme.textTheme.titleSmall?.copyWith(
                        color: muted,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: hasError
                              ? theme.colorScheme.error
                              : theme.colorScheme.outlineVariant,
                          width: hasError ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            StatusPill(kind: kind, label: sourceLabel ?? label, icon: icon),
            if (hasError) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 14,
                    color: colors.error.fg,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      errorText!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.error.fg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (quote != null) ...[
              const SizedBox(height: 10),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 2, color: colors.brass),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.evidenceQuote(quote!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
