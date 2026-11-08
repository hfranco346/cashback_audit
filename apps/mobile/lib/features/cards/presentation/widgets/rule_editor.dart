import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/strings.dart';
import '../../../categories/domain/catalog_entities.dart';
import '../card_form_controller.dart';

/// Pure presentational editor for the per-category reward rules of a card.
class RuleEditor extends StatelessWidget {
  const RuleEditor({
    super.key,
    required this.rules,
    required this.categories,
    required this.capSuffix,
    required this.onAdd,
    required this.onRemove,
    required this.onCategoryChanged,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Set<String> usedByOthers(int i) => {
      for (var j = 0; j < rules.length; j++)
        if (j != i && rules[j].categoryId != null) rules[j].categoryId!,
    };
    final canAdd =
        categories.isNotEmpty &&
        rules.length < categories.length &&
        rules.length < 50;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.rulesTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          S.rulesHelper,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (categories.isEmpty)
          Text(
            S.ruleNeedsCategories,
            key: const Key('rules-need-categories'),
            style: theme.textTheme.bodyMedium,
          ),
        for (var i = 0; i < rules.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RuleRow(
              key: ObjectKey(rules[i]),
              index: i,
              draft: rules[i],
              categories: [
                for (final c in categories)
                  if (!usedByOthers(i).contains(c.id)) c,
              ],
              capSuffix: capSuffix,
              error: errors[i],
              onRemove: () => onRemove(i),
              onCategoryChanged: (id) => onCategoryChanged(i, id),
            ),
          ),
        OutlinedButton.icon(
          key: const Key('add-rule'),
          onPressed: canAdd ? onAdd : null,
          icon: const Icon(Icons.add_rounded),
          label: const Text(S.addRule),
        ),
      ],
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    super.key,
    required this.index,
    required this.draft,
    required this.categories,
    required this.capSuffix,
    required this.onRemove,
    required this.onCategoryChanged,
    this.error,
  });

  final int index;
  final RuleDraft draft;
  final List<Category> categories;
  final String capSuffix;
  final String? error;
  final VoidCallback onRemove;
  final ValueChanged<String?> onCategoryChanged;

  static final _decimalFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'[0-9.,]'),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: error == null
              ? theme.colorScheme.outlineVariant
              : theme.colorScheme.error,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: Key('rule-category-$index'),
                  initialValue: draft.categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: S.ruleCategory),
                  items: [
                    for (final c in categories)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: onCategoryChanged,
                ),
              ),
              IconButton(
                key: Key('remove-rule-$index'),
                tooltip: S.removeRule,
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: Key('rule-rate-$index'),
                  controller: draft.rate,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [_decimalFormatter],
                  decoration: const InputDecoration(
                    labelText: S.ruleRate,
                    suffixText: '%',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: Key('rule-cap-$index'),
                  controller: draft.cap,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [_decimalFormatter],
                  decoration: InputDecoration(
                    labelText: S.ruleCap,
                    helperText: S.ruleCapHelper,
                    suffixText: capSuffix,
                  ),
                ),
              ),
            ],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error!,
                key: Key('rule-error-$index'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
