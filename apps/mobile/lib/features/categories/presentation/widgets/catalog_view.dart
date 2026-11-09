import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../../shared/widgets/atoms/staggered_entrance.dart';
import '../../../../shared/widgets/molecules/inline_message.dart';
import '../../domain/catalog_entities.dart';
import 'dashed_suggestion_tile.dart';

/// Pure presentational "Rubros" tab: a guided empty state while there are no
/// categories, then a card per category with the cards that reward it and
/// its (optional) merchants.
class CatalogView extends StatelessWidget {
  const CatalogView({
    super.key,
    required this.categories,
    required this.merchantsOf,
    required this.loading,
    required this.offline,
    required this.onRefresh,
    required this.onAddCategory,
    required this.onEditCategory,
    required this.onDeleteCategory,
    required this.onAddMerchant,
    required this.onEditMerchant,
    this.ruleTagsOf = _noTags,
    this.onQuickAddCategory,
    this.errorMessage,
  });

  static List<String> _noTags(String categoryId) => const [];

  final List<Category> categories;
  final List<Merchant> Function(String categoryId) merchantsOf;

  /// Labels like `BAC Cash 7%` for the cards that pay this category.
  final List<String> Function(String categoryId) ruleTagsOf;
  final bool loading;
  final bool offline;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final VoidCallback onAddCategory;

  /// Creates a suggested category by name (empty state, one tap).
  final ValueChanged<String>? onQuickAddCategory;
  final ValueChanged<Category> onEditCategory;
  final ValueChanged<Category> onDeleteCategory;
  final ValueChanged<Category> onAddMerchant;
  final ValueChanged<Merchant> onEditMerchant;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final showEmpty = categories.isEmpty && errorMessage == null && !(loading);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.navCategories,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontSize: 32,
                        ),
                      ),
                    ),
                  ),
                  if (categories.isNotEmpty)
                    FilledButton.tonal(
                      key: const Key('add-category'),
                      onPressed: onAddCategory,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text(l10n.catalogNewCategory),
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: onRefresh,
                child: loading && categories.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(child: CircularProgressIndicator()),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        children: [
                          if (offline)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InlineMessage(
                                message: l10n.offlineBanner,
                                tone: InlineMessageTone.info,
                              ),
                            ),
                          if (errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InlineMessage(
                                message: errorMessage!,
                                actionLabel: l10n.retry,
                                onAction: () => onRefresh(),
                              ),
                            ),
                          if (showEmpty)
                            ..._guided(context)
                          else ...[
                            if (categories.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Text(
                                  l10n.catalogOptionalNote,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 13,
                                    height: 1.45,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            for (var i = 0; i < categories.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: StaggeredEntrance(
                                  index: i,
                                  child: _CategoryCard(
                                    key: ValueKey(categories[i].id),
                                    category: categories[i],
                                    merchants: merchantsOf(categories[i].id),
                                    tags: ruleTagsOf(categories[i].id),
                                    initiallyExpanded: i == 0,
                                    onEdit: () => onEditCategory(categories[i]),
                                    onDelete: () =>
                                        onDeleteCategory(categories[i]),
                                    onAddMerchant: () =>
                                        onAddMerchant(categories[i]),
                                    onEditMerchant: onEditMerchant,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _guided(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final suggestions = [
      l10n.onbCatSupermarkets,
      l10n.onbCatPharmacy,
      l10n.onbCatRestaurants,
      l10n.onbCatGas,
    ];
    return [
      StaggeredEntrance(
        index: 0,
        child: DecoratedBox(
          key: const Key('catalog-guide'),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.catalogIntroTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.catalogIntroBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    height: 1.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      StaggeredEntrance(
        index: 1,
        child: SectionHeader(title: l10n.catalogQuickAdd, caption: true),
      ),
      const SizedBox(height: 14),
      for (var i = 0; i < suggestions.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: StaggeredEntrance(
            index: i + 2,
            child: DashedSuggestionTile(
              key: Key('suggest-$i'),
              label: suggestions[i],
              onTap: onQuickAddCategory == null
                  ? null
                  : () => onQuickAddCategory!(suggestions[i]),
            ),
          ),
        ),
      const SizedBox(height: 6),
      StaggeredEntrance(
        index: suggestions.length + 2,
        child: AppButton(
          key: const Key('add-category-empty'),
          label: l10n.catalogCreateOther,
          onPressed: onAddCategory,
        ),
      ),
    ];
  }
}

class _CategoryCard extends StatefulWidget {
  const _CategoryCard({
    super.key,
    required this.category,
    required this.merchants,
    required this.tags,
    required this.initiallyExpanded,
    required this.onEdit,
    required this.onDelete,
    required this.onAddMerchant,
    required this.onEditMerchant,
  });

  final Category category;
  final List<Merchant> merchants;
  final List<String> tags;
  final bool initiallyExpanded;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddMerchant;
  final ValueChanged<Merchant> onEditMerchant;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = widget.category;
    final merchants = widget.merchants;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              expanded: _open,
              child: InkWell(
                key: Key('category-${c.id}'),
                onTap: () => setState(() => _open = !_open),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            merchants.isEmpty
                                ? l10n.catalogByAi
                                : l10n.merchantCount(merchants.length),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                              fontFeatures: appFigures,
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns: _open ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.expand_more_rounded,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (widget.tags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final t in widget.tags) _Tag(label: t),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _open
                  ? _body(context, merchants)
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, List<Merchant> merchants) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = widget.category;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (merchants.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                l10n.noMerchants,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          for (var i = 0; i < merchants.length; i++)
            InkWell(
              key: Key('merchant-${merchants[i].id}'),
              onTap: () => widget.onEditMerchant(merchants[i]),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(0, 10, 8, 10),
                decoration: BoxDecoration(
                  border: i == merchants.length - 1
                      ? null
                      : Border(
                          bottom: BorderSide(color: scheme.outlineVariant),
                        ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchants[i].name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (merchants[i].keywords.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final k in merchants[i].keywords)
                            _Alias(label: k),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          Row(
            children: [
              TextButton(
                key: Key('add-merchant-${c.id}'),
                onPressed: widget.onAddMerchant,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.only(right: 12),
                  alignment: Alignment.centerLeft,
                ),
                child: Text(l10n.catalogAddMerchant),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                key: Key('category-menu-${c.id}'),
                tooltip: l10n.catalogMore,
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: scheme.onSurfaceVariant,
                ),
                onSelected: (v) =>
                    v == 'edit' ? widget.onEdit() : widget.onDelete(),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
                  PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small pill (`.tag`) naming a card that pays a category.
class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(fontSize: 11, color: scheme.onPrimaryContainer),
        ),
      ),
    );
  }
}

/// Statement text exactly as the bank prints it (`.alias`).
class _Alias extends StatelessWidget {
  const _Alias({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Center(
            widthFactor: 1,
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 11,
                letterSpacing: 0.2,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
