import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../shared/widgets/molecules/inline_message.dart';
import '../../domain/catalog_entities.dart';
import '../catalog_controller.dart' show parseKeywords;

/// Bottom-sheet form to create, edit or reassign a merchant. Reused by the
/// verification result screen to assign an unmatched statement line.
///
/// [onSubmit] returns an error message (shown inline) or `null` on success,
/// after which the sheet closes itself.
class MerchantFormSheet extends StatefulWidget {
  const MerchantFormSheet({
    super.key,
    required this.categories,
    required this.onSubmit,
    this.title = S.addMerchant,
    this.initialName = '',
    this.initialKeywords = const [],
    this.initialCategoryId,
  });

  final List<Category> categories;
  final String title;
  final String initialName;
  final List<String> initialKeywords;
  final String? initialCategoryId;
  final Future<String?> Function(
    String name,
    List<String> keywords,
    String categoryId,
  )
  onSubmit;

  @override
  State<MerchantFormSheet> createState() => _MerchantFormSheetState();
}

class _MerchantFormSheetState extends State<MerchantFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  late final _keywords = TextEditingController(
    text: widget.initialKeywords.join(', '),
  );
  String? _categoryId;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initialCategoryId;
  }

  @override
  void dispose() {
    _name.dispose();
    _keywords.dispose();
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
      parseKeywords(_keywords.text),
      _categoryId!,
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
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('merchant-name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: S.merchantName),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return S.fieldRequired;
                  if (t.length > 120) return S.fieldTooLong(120);
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('merchant-keywords'),
                controller: _keywords,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: S.merchantKeywords,
                  helperText: S.merchantKeywordsHelper,
                  helperMaxLines: 3,
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: const Key('merchant-category'),
                initialValue: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: S.merchantCategory,
                ),
                items: [
                  for (final c in widget.categories)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
                validator: (v) => v == null ? S.fieldRequired : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                InlineMessage(message: _error!),
              ],
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('merchant-submit'),
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
      ),
    );
  }
}
