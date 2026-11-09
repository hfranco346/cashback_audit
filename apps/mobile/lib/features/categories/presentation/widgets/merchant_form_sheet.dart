import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/catalog_entities.dart';
import '../catalog_controller.dart' show parseKeywords;

/// Bottom-sheet form to create, edit or reassign a merchant. Reused by the
/// verification result screen to assign an unmatched statement line.
///
/// [onSubmit] returns an error message (shown inline) or `null` on success,
/// after which the sheet closes itself. When [onDelete] is set (edit mode) a
/// "delete" action asks for confirmation and, with the same contract, removes
/// the merchant.
class MerchantFormSheet extends StatefulWidget {
  const MerchantFormSheet({
    super.key,
    required this.categories,
    required this.onSubmit,
    this.onDelete,
    this.title,
    this.initialName = '',
    this.initialKeywords = const [],
    this.initialCategoryId,
  });

  final List<Category> categories;
  final String? title;
  final String initialName;
  final List<String> initialKeywords;
  final String? initialCategoryId;
  final Future<String?> Function(
    String name,
    List<String> keywords,
    String categoryId,
  )
  onSubmit;
  final Future<String?> Function()? onDelete;

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

  Future<void> _run(Future<String?> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await action();
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _run(
      () => widget.onSubmit(
        _name.text.trim(),
        parseKeywords(_keywords.text),
        _categoryId!,
      ),
    );
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteMerchantTitle),
        content: Text(l10n.deleteMerchantBody(widget.initialName)),
        actions: [
          TextButton(
            key: const Key('merchant-delete-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const Key('merchant-delete-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok == true) await _run(widget.onDelete!);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return AppBottomSheet(
      title: widget.title ?? l10n.addMerchant,
      actions: [
        AppButton(
          key: const Key('merchant-submit'),
          label: l10n.save,
          loading: _busy,
          onPressed: _busy ? null : _submit,
        ),
        if (widget.onDelete != null)
          TextButton(
            key: const Key('merchant-delete'),
            onPressed: _busy ? null : _delete,
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: Text(l10n.deleteMerchantTitle),
          ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppField(
              label: l10n.merchantName,
              child: TextFormField(
                key: const Key('merchant-name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: AppField.decoration(),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return l10n.fieldRequired;
                  if (t.length > 120) return l10n.fieldTooLong(120);
                  return null;
                },
              ),
            ),
            const SizedBox(height: 14),
            AppField(
              label: l10n.merchantKeywords,
              help: l10n.merchantKeywordsHelper,
              child: TextFormField(
                key: const Key('merchant-keywords'),
                controller: _keywords,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.characters,
                decoration: AppField.decoration(),
              ),
            ),
            const SizedBox(height: 14),
            AppField(
              label: l10n.merchantCategory,
              child: DropdownButtonFormField<String>(
                key: const Key('merchant-category'),
                initialValue: _categoryId,
                isExpanded: true,
                decoration: AppField.decoration(),
                items: [
                  for (final c in widget.categories)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
                validator: (v) => v == null ? l10n.fieldRequired : null,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              InlineNotice(message: _error!),
            ],
          ],
        ),
      ),
    );
  }
}
