import 'package:flutter/material.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/catalog_entities.dart';

/// Creates a category by name and returns it; throws [AppException] on
/// failure (its message is shown inside the sheet).
typedef CreateCategory = Future<Category> Function(String name);

/// Categories above which the picker shows a search field.
const categorySearchThreshold = 8;

/// Opens the category picker and returns the chosen category id (or `null`
/// when dismissed). A category created from the sheet is returned selected.
Future<String?> showCategoryPicker({
  required BuildContext context,
  required List<Category> categories,
  String? selectedId,
  Set<String> excludedIds = const {},
  CreateCategory? onCreate,
}) => showAppBottomSheet<String>(
  context: context,
  builder: (_) => CategoryPickerSheet(
    categories: categories,
    selectedId: selectedId,
    excludedIds: excludedIds,
    onCreate: onCreate,
  ),
);

/// Bottom sheet listing every category with its full name (wrapping to as
/// many lines as needed), a check on the selected one, a search field when
/// there are many, and "Create category" at the end. Pops the chosen id.
class CategoryPickerSheet extends StatefulWidget {
  const CategoryPickerSheet({
    super.key,
    required this.categories,
    this.selectedId,
    this.excludedIds = const {},
    this.onCreate,
  });

  final List<Category> categories;
  final String? selectedId;

  /// Categories not offered (e.g. already used by another rule).
  final Set<String> excludedIds;
  final CreateCategory? onCreate;

  @override
  State<CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<CategoryPickerSheet> {
  final _search = TextEditingController();
  final _newName = TextEditingController();
  bool _creating = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _search.dispose();
    _newName.dispose();
    super.dispose();
  }

  List<Category> get _available => [
    for (final c in widget.categories)
      if (!widget.excludedIds.contains(c.id)) c,
  ];

  Future<void> _create() async {
    final l10n = context.l10n;
    final name = _newName.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.fieldRequired);
      return;
    }
    if (name.length > 80) {
      setState(() => _error = l10n.fieldTooLong(80));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final created = await widget.onCreate!(name);
      if (mounted) Navigator.of(context).pop(created.id);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = userMessageFor(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final available = _available;
    final query = _search.text.trim().toLowerCase();
    final shown = [
      for (final c in available)
        if (query.isEmpty || c.name.toLowerCase().contains(query)) c,
    ];
    final searchable = available.length > categorySearchThreshold;
    return AppBottomSheet(
      title: l10n.categoryPickerTitle,
      child: Column(
        key: const Key('category-picker'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (searchable) ...[
            TextField(
              key: const Key('category-search'),
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: AppField.decoration(hint: l10n.categoryPickerSearch)
                  .copyWith(prefixIcon: const Icon(Icons.search_rounded)),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                available.isEmpty
                    ? l10n.ruleNeedsCategories
                    : l10n.categoryPickerEmpty,
                key: const Key('category-picker-empty'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final c in shown)
            _CategoryTile(
              key: Key('category-option-${c.id}'),
              name: c.name,
              selected: c.id == widget.selectedId,
              onTap: () => Navigator.of(context).pop(c.id),
            ),
          if (widget.onCreate != null) ...[
            Divider(color: scheme.outlineVariant, height: 1),
            if (!_creating)
              ListTile(
                key: const Key('category-create'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_rounded),
                title: Text(
                  l10n.categoryPickerCreate,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
                onTap: () => setState(() {
                  _creating = true;
                  _newName.text = _search.text.trim();
                }),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppField(
                      label: l10n.categoryName,
                      child: TextField(
                        key: const Key('category-new-name'),
                        controller: _newName,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: AppField.decoration().copyWith(
                          errorText: _error,
                        ),
                        onSubmitted: (_) => _busy ? null : _create(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      key: const Key('category-create-confirm'),
                      label: l10n.categoryPickerCreateConfirm,
                      loading: _busy,
                      onPressed: _busy ? null : _create,
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    super.key,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.field),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.check_rounded, color: scheme.primary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A form-style field that shows the chosen category's full name (wrapping)
/// and opens the picker on tap. Presentational: the caller supplies the
/// current name and what happens on tap.
class CategoryPickerField extends StatelessWidget {
  const CategoryPickerField({
    super.key,
    required this.name,
    required this.hint,
    required this.onTap,
    this.errorText,
    this.compact = false,
  });

  final String? name;
  final String hint;
  final VoidCallback onTap;
  final String? errorText;

  /// Borderless variant for rows inside a panel.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasName = name != null && name!.isNotEmpty;
    final text = Text(
      hasName ? name! : hint,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: hasName ? FontWeight.w700 : FontWeight.w500,
        color: hasName ? scheme.onSurface : scheme.onSurfaceVariant,
      ),
    );
    final row = Row(
      children: [
        Expanded(child: text),
        const SizedBox(width: 6),
        Icon(
          Icons.unfold_more_rounded,
          size: 20,
          color: scheme.onSurfaceVariant,
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.field),
            child: compact
                ? ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: row,
                    ),
                  )
                : Container(
                    constraints: const BoxConstraints(minHeight: 52),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.field),
                      border: Border.all(
                        color: errorText == null
                            ? scheme.outlineVariant
                            : scheme.error,
                      ),
                    ),
                    child: row,
                  ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              errorText!,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ),
      ],
    );
  }
}
