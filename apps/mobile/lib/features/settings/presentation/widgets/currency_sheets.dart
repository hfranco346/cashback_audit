import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/ui/molecules/inverted_rate_hint.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/rate_direction.dart';

final _codePattern = RegExp(r'^[A-Za-z]{3}$');

/// Asks for a 3-letter ISO currency code. Pops the uppercased code.
Future<String?> showCurrencyCodeSheet(
  BuildContext context, {
  required String title,
  List<String> suggestions = const [],
}) => showAppBottomSheet<String>(
  context: context,
  builder: (_) => _CurrencyCodeSheet(title: title, suggestions: suggestions),
);

class _CurrencyCodeSheet extends StatefulWidget {
  const _CurrencyCodeSheet({required this.title, required this.suggestions});

  final String title;
  final List<String> suggestions;

  @override
  State<_CurrencyCodeSheet> createState() => _CurrencyCodeSheetState();
}

class _CurrencyCodeSheetState extends State<_CurrencyCodeSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (!_codePattern.hasMatch(code)) {
      setState(() => _error = context.l10n.currencyInvalid);
      return;
    }
    Navigator.of(context).pop(code.toUpperCase());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppBottomSheet(
      title: widget.title,
      actions: [
        AppButton(
          key: const Key('currency-sheet-save'),
          label: l10n.save,
          onPressed: _submit,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.suggestions.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              children: [
                for (final code in widget.suggestions)
                  AppChip(
                    key: Key('currency-suggestion-$code'),
                    label: code,
                    onTap: () => Navigator.of(context).pop(code),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          AppField(
            label: l10n.curCodeLabel,
            child: TextField(
              key: const Key('currency-code-field'),
              controller: _controller,
              autofocus: true,
              maxLength: 3,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
              ],
              onSubmitted: (_) => _submit(),
              decoration: AppField.decoration(hint: 'USD')
                  .copyWith(errorText: _error),
            ),
          ),
        ],
      ),
    );
  }
}

/// Result of the rate sheet: a rate, or [clear] to erase the stored one.
class RateSheetResult {
  const RateSheetResult.set(Decimal this.rate) : clear = false;
  const RateSheetResult.clear() : rate = null, clear = true;

  final Decimal? rate;
  final bool clear;
}

/// "1 USD = how many HNL?" editor for the last exchange rate of [code]. The
/// stronger currency is the unit whichever side is [primary]; [current] and
/// the returned rate are in the API direction (primary units per 1 [code]).
Future<RateSheetResult?> showRateSheet(
  BuildContext context, {
  required String code,
  required String primary,
  Decimal? current,
}) => showAppBottomSheet<RateSheetResult>(
  context: context,
  builder: (_) => _RateSheet(code: code, primary: primary, current: current),
);

/// Parses a typed rate: `> 0`, at most 6 decimals. Accepts `,` as separator.
Decimal? parseRateInput(String raw) {
  final d = Decimal.tryParse(raw.trim().replaceAll(',', '.'));
  if (d == null || d <= Decimal.zero || d.scale > 6) return null;
  return d;
}

class _RateSheet extends StatefulWidget {
  const _RateSheet({
    required this.code,
    required this.primary,
    required this.current,
  });

  final String code;
  final String primary;
  final Decimal? current;

  @override
  State<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<_RateSheet> {
  late final RateDirection _direction = RateDirection.choose(
    primary: widget.primary,
    other: widget.code,
    knownStored: widget.current,
  );
  late final _controller = TextEditingController(
    text: widget.current == null
        ? ''
        : _direction.toShown(widget.current!).toString(),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final shown = parseRateInput(_controller.text);
    final rate = shown == null ? null : _direction.toStored(shown);
    if (rate == null) {
      setState(() => _error = context.l10n.curRateInvalid);
      return;
    }
    Navigator.of(context).pop(RateSheetResult.set(rate));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppBottomSheet(
      title: l10n.curEditRate,
      actions: [
        AppButton(
          key: const Key('rate-sheet-save'),
          label: l10n.save,
          onPressed: _submit,
        ),
        if (widget.current != null)
          AppButton.ghost(
            key: const Key('rate-sheet-clear'),
            label: l10n.curRateClear,
            onPressed: () =>
                Navigator.of(context).pop(const RateSheetResult.clear()),
          ),
      ],
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppField(
              label: l10n.curRateQuestion(_direction.unit, _direction.quote),
              child: TextField(
                key: const Key('rate-field'),
                controller: _controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onSubmitted: (_) => _submit(),
                decoration: AppField.decoration(
                  prefix: '1 ${_direction.unit} = ',
                  suffix: _direction.quote,
                ).copyWith(errorText: _error),
              ),
            ),
            InvertedRateHint(
              direction: _direction,
              shown: parseRateInput(_controller.text),
              onUse: (value) => _controller.text = value.toString(),
            ),
          ],
        ),
      ),
    );
  }
}
