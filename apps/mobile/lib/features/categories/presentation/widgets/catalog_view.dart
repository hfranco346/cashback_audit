import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../shared/widgets/atoms/staggered_entrance.dart';
import '../../../../shared/widgets/molecules/empty_state.dart';
import '../../../../shared/widgets/molecules/inline_message.dart';
import '../../domain/catalog_entities.dart';

/// Pure presentational list of categories with their merchants.
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
    required this.onDeleteMerchant,
    this.errorMessage,
  });

  final List<Category> categories;
  final List<Merchant> Function(String categoryId) merchantsOf;
  final bool loading;
  final bool offline;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final VoidCallback onAddCategory;
  final ValueChanged<Category> onEditCategory;
  final ValueChanged<Category> onDeleteCategory;
  final ValueChanged<Category> onAddMerchant;
  final ValueChanged<Merchant> onEditMerchant;
  final ValueChanged<Merchant> onDeleteMerchant;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.catalogTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-category'),
        onPressed: onAddCategory,
        icon: const Icon(Icons.add_rounded),
        label: Text(S.addCategory),
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: Builder(
          builder: (context) {
            if (loading && categories.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (categories.isEmpty && errorMessage == null) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.6,
                    child: EmptyState(
                      icon: Icons.category_rounded,
                      title: S.catalogEmptyTitle,
                      message: S.catalogEmptyBody,
                      actionLabel: S.addCategory,
                      onAction: onAddCategory,
                    ),
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
              children: [
                if (offline)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: InlineMessage(
                      message: S.offlineBanner,
                      tone: InlineMessageTone.info,
                    ),
                  ),
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InlineMessage(
                      message: errorMessage!,
                      actionLabel: S.retry,
                      onAction: () => onRefresh(),
                    ),
                  ),
                for (var i = 0; i < categories.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: StaggeredEntrance(
                      index: i,
                      child: _CategoryCard(
                        category: categories[i],
                        merchants: merchantsOf(categories[i].id),
                        onEdit: () => onEditCategory(categories[i]),
                        onDelete: () => onDeleteCategory(categories[i]),
                        onAddMerchant: () => onAddMerchant(categories[i]),
                        onEditMerchant: onEditMerchant,
                        onDeleteMerchant: onDeleteMerchant,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.merchants,
    required this.onEdit,
    required this.onDelete,
    required this.onAddMerchant,
    required this.onEditMerchant,
    required this.onDeleteMerchant,
  });

  final Category category;
  final List<Merchant> merchants;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddMerchant;
  final ValueChanged<Merchant> onEditMerchant;
  final ValueChanged<Merchant> onDeleteMerchant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('category-${category.id}'),
          tilePadding: EdgeInsets.fromLTRB(16, 4, 4, 4),
          childrenPadding: EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Text(category.name, style: theme.textTheme.titleMedium),
          subtitle: Text(S.merchantCount(merchants.length)),
          trailing: PopupMenuButton<String>(
            key: Key('category-menu-${category.id}'),
            onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text(S.edit)),
              PopupMenuItem(value: 'delete', child: Text(S.delete)),
            ],
          ),
          children: [
            if (merchants.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    S.noMerchants,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            for (final m in merchants)
              ListTile(
                key: Key('merchant-${m.id}'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(m.name),
                subtitle: m.keywords.isEmpty
                    ? null
                    : Text(
                        m.keywords.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                onTap: () => onEditMerchant(m),
                trailing: IconButton(
                  tooltip: S.delete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => onDeleteMerchant(m),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: Key('add-merchant-${category.id}'),
                onPressed: onAddMerchant,
                icon: const Icon(Icons.add_rounded),
                label: Text(S.addMerchant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
