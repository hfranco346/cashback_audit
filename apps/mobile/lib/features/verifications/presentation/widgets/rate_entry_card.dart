import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/ui/ui.dart';
import '../confirm_rates_controller.dart';

/// One rate to confirm: the base rate or one category, as a design
/// [RateField] with its source label (statement + quote / card rules /
/// previous / required) and, for categories, the optional monthly cap.
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

  RateSource get _source => switch (entry.origin) {
    RateOrigin.statement => RateSource.detected,
    RateOrigin.cardRule => RateSource.cardRules,
    RateOrigin.previous => RateSource.previous,
    RateOrigin.none => RateSource.required,
  };

  @override
  Widget build(BuildContext context) {
    final showError = entry.hasRate || entry.touched;
    return RateField(
      title: entry.name,
      subtitle: subtitle,
      source: _source,
      controller: entry.rate,
      fieldKey: Key('rate-field-$_slug'),
      quote: entry.evidence,
      errorText: showError ? entry.rateError : null,
      onChanged: (_) => onTouched(),
      onTapOutside: onTouched,
      footer: entry.isBase
          ? (entry.unitNote == null ? null : _UnitNote(entry.unitNote!))
          : _CapEditor(
              key: Key('cap-editor-$_slug'),
              entry: entry,
              suffix: capSuffix,
              unitNote: entry.unitNote,
            ),
    );
  }
}

class _UnitNote extends StatelessWidget {
  const _UnitNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}

/// "+ Monthly cap (optional)": collapsed until tapped (or until it has a
/// value, e.g. when recalculating).
class _CapEditor extends StatefulWidget {
  const _CapEditor({
    super.key,
    required this.entry,
    required this.suffix,
    this.unitNote,
  });

  final RateEntryDraft entry;
  final String suffix;
  final String? unitNote;

  @override
  State<_CapEditor> createState() => _CapEditorState();
}

class _CapEditorState extends State<_CapEditor> {
  late bool _open = widget.entry.cap.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final entry = widget.entry;
    final slug = entry.categoryId ?? 'base';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.unitNote != null) _UnitNote(widget.unitNote!),
        if (!_open)
          TextButton(
            key: Key('rate-cap-add-$slug'),
            onPressed: () => setState(() => _open = true),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(48, 36),
              alignment: Alignment.centerLeft,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(l10n.rateCapAdd),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              key: Key('rate-cap-$slug'),
              controller: entry.cap,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [RateEntryCard._decimal],
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              decoration: AppField.decoration(suffix: widget.suffix).copyWith(
                labelText: l10n.rateCapLabel,
                errorText: entry.capError,
              ),
            ),
          ),
      ],
    );
  }
}
