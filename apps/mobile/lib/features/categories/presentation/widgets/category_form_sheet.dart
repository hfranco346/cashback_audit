import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/ui/ui.dart';
import '../../../../shared/widgets/molecules/inline_message.dart';

/// Bottom-sheet form to create or rename a category.
class CategoryFormSheet extends StatefulWidget {
  const CategoryFormSheet({
    super.key,
    required this.onSubmit,
    this.title,
    this.initialName = '',
    this.initialDescription = '',
  });

  final String? title;
  final String initialName;
  final String initialDescription;
  final Future<String?> Function(String name, String description) onSubmit;

  @override
  State<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  late final _description = TextEditingController(
    text: widget.initialDescription,
  );
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onSubmit(
      _name.text.trim(),
      _description.text.trim(),
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppBottomSheet(
      title: widget.title ?? l10n.addCategory,
      actions: [
        AppButton(
          key: const Key('category-submit'),
          label: l10n.save,
          loading: _busy,
          onPressed: _busy ? null : _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppField(
              label: l10n.categoryName,
              child: TextFormField(
                key: const Key('category-name'),
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: AppField.decoration(),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return l10n.fieldRequired;
                  if (t.length > 80) return l10n.fieldTooLong(80);
                  return null;
                },
              ),
            ),
            const SizedBox(height: 14),
            AppField(
              label: l10n.categoryDescription,
              child: TextFormField(
                key: const Key('category-description'),
                controller: _description,
                maxLength: 500,
                decoration: AppField.decoration(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              InlineMessage(message: _error!),
            ],
          ],
        ),
      ),
    );
  }
}
