import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../confirm_rates_controller.dart';

/// One rate to confirm: the base rate or one category. Shows where the
/// prefilled value came from (statement quote, card rule, previous audit) or
/// marks the field as required when there is nothing to prefill.
class RateEntryCard extends StatelessWidget {
  const RateEntryCard({
    super.key,
    required this.entry,
    required this.capSuffix,
    required this.onTouched,
    this.subtitle,
  });

  final RateEntryDraft entry;
  final String capSuffix;
  final VoidCallback onTouched;
  final String? subtitle;

  static final _decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

  String get _slug => entry.categoryId ?? 'base';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showError = entry.hasRate || entry.touched;
    final rateError = showError ? entry.rateError : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    entry.name,
                    key: Key('rate-title-$_slug'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                RateOriginBadge(
                  key: Key('rate-badge-$_slug'),
                  origin: entry.origin,
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (entry.evidence != null) ...[
              const SizedBox(height: 10),
              Container(
                key: Key('rate-evidence-$_slug'),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  S.evidenceQuote(entry.evidence!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            if (entry.unitNote != null) ...[
              const SizedBox(height: 6),
              Text(entry.unitNote!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            TextField(
              key: Key('rate-field-$_slug'),
              controller: entry.rate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [_decimal],
              onChanged: (_) => onTouched(),
              onTapOutside: (_) => onTouched(),
              decoration: InputDecoration(
                labelText: S.rateFieldLabel,
                suffixText: '%',
                errorText: rateError,
              ),
            ),
            if (!entry.isBase) ...[
              const SizedBox(height: 10),
              TextField(
                key: Key('rate-cap-$_slug'),
                controller: entry.cap,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [_decimal],
                decoration: InputDecoration(
                  labelText: S.rateCapLabel,
                  suffixText: capSuffix,
                  errorText: entry.capError,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Origin chip: statement / card rule / previous audit / required.
class RateOriginBadge extends StatelessWidget {
  const RateOriginBadge({super.key, required this.origin});

  final RateOrigin origin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = context.statusColors;
    final verdicts = context.verdictColors;
    final (label, icon, fg, bg) = switch (origin) {
      RateOrigin.statement => (
        S.badgeStatement,
        Icons.description_outlined,
        status.success,
        status.successContainer,
      ),
      RateOrigin.cardRule => (
        S.badgeCardRule,
        Icons.credit_card_rounded,
        theme.colorScheme.onSecondaryContainer,
        theme.colorScheme.secondaryContainer,
      ),
      RateOrigin.previous => (
        S.badgePrevious,
        Icons.history_rounded,
        theme.colorScheme.onSecondaryContainer,
        theme.colorScheme.secondaryContainer,
      ),
      RateOrigin.none => (
        S.badgeRequired,
        Icons.edit_note_rounded,
        verdicts.warning,
        verdicts.warningContainer,
      ),
    };
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
