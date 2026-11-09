import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../domain/catalog_entities.dart';

/// Asks which category to move a category's merchants and card rules to
/// before deleting it (`CATEGORY_IN_USE`). Pops the chosen category id, or
/// null when cancelled.
class CategoryReassignDialog extends StatefulWidget {
  const CategoryReassignDialog({
    super.key,
    required this.others,
    required this.message,
  });

  final List<Category> others;
  final String message;

  @override
  State<CategoryReassignDialog> createState() => _CategoryReassignDialogState();
}

class _CategoryReassignDialogState extends State<CategoryReassignDialog> {
  late String _target = widget.others.first.id;

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
          DropdownButtonFormField<String>(
            key: const Key('reassign-target'),
            initialValue: _target,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.reassignTo),
            items: [
              for (final c in widget.others)
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) => setState(() => _target = v ?? _target),
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
