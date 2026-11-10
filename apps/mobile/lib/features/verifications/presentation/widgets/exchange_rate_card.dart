import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/molecules/inverted_rate_hint.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/decimal_utils.dart';
import '../../../../core/utils/rate_direction.dart';
import '../../../cards/domain/card_validator.dart';
import '../confirm_rates_controller.dart' show RateOrigin;

final _decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

/// What the live preview talks about.
enum RatePreviewKind { reward, purchases }

/// "1 USD = how many HNL?": the currency is fixed on each side of the field
/// (the stronger one is the unit, so the number is >= 1), a live preview shows
/// the effect and an upside-down value gets a flip hint. Required (cashback
/// conversion) or optional (purchases in a foreign currency).
class ExchangeRateCard extends StatelessWidget {
  const ExchangeRateCard({
    super.key,
    required this.title,
    this.unit,
    required this.target,
    required this.controller,
    required this.fieldKey,
    required this.origin,
    required this.isRequired,
    this.body,
    this.error,
    this.onTouched,
    this.statementNote,
    this.emptyNote,
    this.emptyNoteKey,
    this.showFindHint = true,
    this.direction,
    this.previewAmount,
    this.previewKind = RatePreviewKind.purchases,
  });

  final String title;

  /// Explanation under the title (why the rate is needed).
  final String? body;

  /// Currency of the "1 X" chip; null (legacy single rate) shows only the
  /// field.
  final String? unit;

  /// Currency the answer is expressed in (suffix of the field).
  final String target;
  final TextEditingController controller;
  final Key fieldKey;
  final RateOrigin origin;
  final bool isRequired;

  /// Inline error (already filtered by the container: shown once touched).
  final String? error;
  final VoidCallback? onTouched;

  /// "Your statement says 1 USD = 26.35 HNL."
  final String? statementNote;

  /// Muted note shown while an optional field is empty.
  final String? emptyNote;
  final Key? emptyNoteKey;
  final bool showFindHint;

  /// Unit/answer currencies and API conversion; `null` for the legacy
  /// "any foreign currency" field (no preview, no flip hint).
  final RateDirection? direction;

  /// Amount in the other currency the preview converts (the reported reward
  /// or the purchases in that currency); an example is shown when null.
  final Decimal? previewAmount;
  final RatePreviewKind previewKind;

  String? _previewText(BuildContext context) {
    final d = direction;
    if (d == null) return null;
    final shown = CardValidator.parse(controller.text);
    if (shown == null) return null;
    final stored = d.toStored(shown);
    if (stored == null) return null;
    final l10n = context.l10n;
    final amount = previewAmount;
    if (amount != null && amount > Decimal.zero) {
      final from = formatMoney(amount, currency: d.other);
      final to = formatMoney(amount * stored, currency: d.primary);
      return previewKind == RatePreviewKind.reward
          ? l10n.ratePreviewReward(from, to)
          : l10n.ratePreviewPurchases(from, to);
    }
    final base = Decimal.fromInt(100);
    return l10n.ratePreviewExample(
      formatMoney(base, currency: d.unit),
      formatMoney(base * shown, currency: d.quote),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.appColors;
    final muted = theme.colorScheme.onSurfaceVariant;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final empty = controller.text.trim().isEmpty;
        final missing = isRequired && empty;
        final (kind, icon, label) = switch (origin) {
          RateOrigin.statement => (
            StatusKind.ok,
            Icons.description_outlined,
            l10n.rateSourceStatement,
          ),
          RateOrigin.lastRate => (
            StatusKind.neutral,
            Icons.history_rounded,
            l10n.rateSourceLast,
          ),
          RateOrigin.previous => (
            StatusKind.neutral,
            Icons.history_rounded,
            l10n.badgePrevious,
          ),
          RateOrigin.cardRule => (
            StatusKind.neutral,
            Icons.credit_card_rounded,
            l10n.badgeCardRule,
          ),
          RateOrigin.none when isRequired => (
            StatusKind.error,
            Icons.error_outline_rounded,
            l10n.badgeRequired,
          ),
          RateOrigin.none => (
            StatusKind.neutral,
            Icons.edit_outlined,
            l10n.foreignRateOptional,
          ),
        };
        final red = missing || error != null;
        final message = missing && unit != null
            ? l10n.exchangeEnterHint(unit!, target)
            : error;
        return Card(
          shape: red
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  side: BorderSide(color: theme.colorScheme.error, width: 2),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: StatusPill(kind: kind, label: label, icon: icon),
                    ),
                  ],
                ),
                if (body != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    body!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: muted,
                      height: 1.45,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (unit != null) ...[
                  Text(
                    l10n.exchangeQuestion(unit!, target),
                    style: theme.textTheme.titleSmall?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    if (unit != null) ...[
                      Container(
                        constraints: const BoxConstraints(minHeight: 52),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(AppRadii.field),
                        ),
                        child: Text(
                          '1 $unit',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontFeatures: appFigures,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '=',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: muted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: TextField(
                        key: fieldKey,
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [_decimal],
                        onChanged: (_) => onTouched?.call(),
                        onTapOutside: onTouched == null
                            ? null
                            : (_) => onTouched!(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFeatures: appFigures,
                        ),
                        decoration:
                            AppField.decoration(
                              hint: '26.00',
                              suffix: target,
                            ).copyWith(
                              enabledBorder: red
                                  ? OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.field,
                                      ),
                                      borderSide: BorderSide(
                                        color: theme.colorScheme.error,
                                        width: 2,
                                      ),
                                    )
                                  : null,
                            ),
                      ),
                    ),
                  ],
                ),
                if (direction != null)
                  InvertedRateHint(
                    direction: direction!,
                    shown: CardValidator.parse(controller.text),
                    onUse: (value) {
                      controller.text = decimalToApi(value);
                      onTouched?.call();
                    },
                  ),
                if (_previewText(context) case final preview?) ...[
                  const SizedBox(height: 8),
                  Text(
                    preview,
                    key: const Key('rate-preview'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: appFigures,
                    ),
                  ),
                ],
                if (empty && direction?.exampleShown != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.rateExampleHelper(
                      direction!.unit,
                      formatExchangeRate(direction!.exampleShown!),
                      direction!.quote,
                    ),
                    key: const Key('rate-example'),
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
                if (message != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 14,
                        color: colors.error.fg,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          message,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.error.fg,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (statementNote != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    statementNote!,
                    key: const Key('statement-rate-note'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (!isRequired && empty && emptyNote != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    emptyNote!,
                    key: emptyNoteKey,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
                if (showFindHint && isRequired) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.exchangeFindHint,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
