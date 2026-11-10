import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/catalog_entities.dart';
import 'category_picker_sheet.dart';

/// Asks which category to move a category's merchants and card rules to
/// before deleting it (`CATEGORY_IN_USE`). Pops the chosen category id, or
/// null when cancelled.
class CategoryReassignDialog extends StatefulWidget {
  const CategoryReassignDialog({
    super.key,
    required this.others,
    required this.message,
    this.onCreateCategory,
  });

  final List<Category> others;

  /// Lets the picker create the destination category inline.
  final CreateCategory? onCreateCategory;
  final String message;

  @override
  State<CategoryReassignDialog> createState() => _CategoryReassignDialogState();
}

class _CategoryReassignDialogState extends State<CategoryReassignDialog> {
  late String _target = widget.others.first.id;
  final _created = <Category>[];

  List<Category> get _all => [...widget.others, ..._created];

  Future<void> _pick() async {
    final id = await showCategoryPicker(
      context: context,
      categories: _all,
      selectedId: _target,
      onCreate: widget.onCreateCategory == null
          ? null
          : (name) async {
              final c = await widget.onCreateCategory!(name);
              _created.add(c);
              return c;
            },
    );
    if (id != null && mounted) setState(() => _target = id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.deleteCategoryTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 16),
          AppField(
            label: l10n.reassignTo,
            child: CategoryPickerField(
              key: const Key('reassign-target'),
              name: _all
                  .where((c) => c.id == _target)
                  .map((c) => c.name)
                  .firstOrNull,
              hint: l10n.ruleCategory,
              onTap: _pick,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('reassign-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('reassign-confirm'),
          onPressed: () => Navigator.of(context).pop(_target),
          style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
          child: Text(l10n.reassignAndDelete),
        ),
      ],
    );
  }
}
