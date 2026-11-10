import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../categories/domain/catalog_entities.dart';
import '../../../categories/presentation/widgets/category_picker_sheet.dart';
import '../card_form_controller.dart';

/// Pure presentational editor for the per-category reward rules of a card:
/// one bordered panel, a row per rule (category, % pill, remove) and a
/// "+ add category" action. The optional monthly cap opens under its row.
class RuleEditor extends StatelessWidget {
  const RuleEditor({
    super.key,
    required this.rules,
    required this.categories,
    required this.capSuffix,
    required this.onAdd,
    required this.onRemove,
    required this.onCategoryChanged,
    this.onCreateCategory,
    this.errors = const {},
  });

  final List<RuleDraft> rules;
  final List<Category> categories;

  /// Unit of the monthly cap: currency code or `pts`.
  final String capSuffix;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final void Function(int index, String? categoryId) onCategoryChanged;
  final Map<int, String> errors;

  /// Lets the picker create a category inline (and select it).
  final CreateCategory? onCreateCategory;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Set<String> usedByOthers(int i) => {
      for (var j = 0; j < rules.length; j++)
        if (j != i && rules[j].categoryId != null) rules[j].categoryId!,
    };
    final canAdd =
        (onCreateCategory != null || rules.length < categories.length) &&
        rules.length < 50;
    return AppField(
      label: l10n.cardRulesTitle,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (categories.isEmpty && onCreateCategory == null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  l10n.ruleNeedsCategories,
                  key: const Key('rules-need-categories'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (var i = 0; i < rules.length; i++)
              _RuleRow(
                key: ObjectKey(rules[i]),
                index: i,
                draft: rules[i],
                categories: categories,
                excludedIds: usedByOthers(i),
                onCreateCategory: onCreateCategory,
                capSuffix: capSuffix,
                error: errors[i],
                onRemove: () => onRemove(i),
                onCategoryChanged: (id) => onCategoryChanged(i, id),
              ),
            TextButton(
              key: const Key('add-rule'),
              onPressed: canAdd ? onAdd : null,
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: const RoundedRectangleBorder(),
              ),
              child: Text(l10n.cardAddRule),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleRow extends StatefulWidget {
  const _RuleRow({
    super.key,
    required this.index,
    required this.draft,
    required this.categories,
    required this.excludedIds,
    required this.capSuffix,
    required this.onRemove,
    required this.onCategoryChanged,
    this.onCreateCategory,
    this.error,
  });

  final int index;
  final RuleDraft draft;
  final List<Category> categories;
  final Set<String> excludedIds;
  final CreateCategory? onCreateCategory;
  final String capSuffix;
  final String? error;
  final VoidCallback onRemove;
  final ValueChanged<String?> onCategoryChanged;

  @override
  State<_RuleRow> createState() => _RuleRowState();
}

class _RuleRowState extends State<_RuleRow> {
  static final _decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

  late bool _showCap = widget.draft.cap.text.isNotEmpty;

  Future<void> _pickCategory() async {
    final id = await showCategoryPicker(
      context: context,
      categories: widget.categories,
      selectedId: widget.draft.categoryId,
      excludedIds: widget.excludedIds,
      onCreate: widget.onCreateCategory,
    );
    if (id != null) widget.onCategoryChanged(id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final i = widget.index;
    final hasError = widget.error != null;
    final borderColor = hasError ? scheme.error : scheme.outlineVariant;
    OutlineInputBorder outline(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: c),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: CategoryPickerField(
                  key: Key('rule-category-$i'),
                  compact: true,
                  name: widget.categories
                      .where((c) => c.id == widget.draft.categoryId)
                      .map((c) => c.name)
                      .firstOrNull,
                  hint: l10n.ruleCategory,
                  onTap: _pickCategory,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 78,
                child: TextField(
                  key: Key('rule-rate-$i'),
                  controller: widget.draft.rate,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [_decimal],
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    suffixText: '%',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    constraints: const BoxConstraints(minHeight: 40),
                    fillColor: scheme.surface,
                    border: outline(borderColor),
                    enabledBorder: outline(borderColor),
                  ),
                ),
              ),
              IconButton(
                key: Key('remove-rule-$i'),
                tooltip: l10n.removeRule,
                onPressed: widget.onRemove,
                icon: const Icon(Icons.remove_rounded, size: 18),
              ),
            ],
          ),
          if (_showCap)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8, bottom: 4),
              child: TextField(
                key: Key('rule-cap-$i'),
                controller: widget.draft.cap,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [_decimal],
                decoration: InputDecoration(
                  isDense: true,
                  labelText: '${l10n.ruleCap} · ${l10n.ruleCapHelper}',
                  suffixText: widget.capSuffix,
                  constraints: const BoxConstraints(minHeight: 44),
                ),
              ),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: Key('add-cap-$i'),
                onPressed: () => setState(() => _showCap = true),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: EdgeInsets.zero,
                  textStyle: theme.textTheme.labelMedium,
                ),
                child: Text(l10n.cardAddCap),
              ),
            ),
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, right: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: scheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.error!,
                      key: Key('rule-error-$i'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
