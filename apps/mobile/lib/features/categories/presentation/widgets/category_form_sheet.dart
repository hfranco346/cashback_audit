import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../shared/widgets/molecules/inline_message.dart';

/// Bottom-sheet form to create or rename a category.
class CategoryFormSheet extends StatefulWidget {
  const CategoryFormSheet({
    super.key,
    required this.onSubmit,
    this.title = S.addCategory,
    this.initialName = '',
    this.initialDescription = '',
  });

  final String title;
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
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('category-name'),
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: S.categoryName),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return S.fieldRequired;
                if (t.length > 80) return S.fieldTooLong(80);
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('category-description'),
              controller: _description,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: S.categoryDescription,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              InlineMessage(message: _error!),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('category-submit'),
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Text(S.save),
            ),
          ],
        ),
      ),
    );
  }
}
