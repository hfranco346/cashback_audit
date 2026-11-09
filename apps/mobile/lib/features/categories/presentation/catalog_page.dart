import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/ui/ui.dart';
import '../../../core/utils/decimal_utils.dart';
import '../../cards/domain/card_entities.dart';
import '../../cards/presentation/cards_controller.dart';
import '../domain/catalog_entities.dart';
import 'catalog_controller.dart';
import 'widgets/catalog_view.dart';
import 'widgets/category_form_sheet.dart';
import 'widgets/category_reassign_dialog.dart';
import 'widgets/merchant_form_sheet.dart';

/// Container for the "Rubros" tab: categories and merchants management.
class CatalogPage extends GetView<CatalogController> {
  const CatalogPage({super.key, this.cards});

  /// Cards whose rules label each category; defaults to the registered one.
  final CardsController? cards;

  CardsController? _cards() =>
      cards ??
      (Get.isRegistered<CardsController>()
          ? Get.find<CardsController>()
          : null);

  void _notify(BuildContext context, String title, [String? body]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(body == null ? title : '$title\n$body')),
    );
  }

  /// `BAC Cash 7%` labels per category id, for every card with a rule on it.
  /// Read inside `Obx` so it follows the cards list.
  Map<String, List<String>> _tags(BuildContext context) {
    final l10n = context.l10n;
    final out = <String, List<String>>{};
    for (final card in _cards()?.cards.toList() ?? const <CreditCard>[]) {
      for (final rule in card.rules) {
        (out[rule.categoryId] ??= []).add(
          l10n.catalogRuleTag(card.alias, formatRate(rule.ratePercent)),
        );
      }
    }
    return out;
  }

  Future<void> _quickAdd(BuildContext context, String name) async {
    final error = await controller.createCategory(name, null);
    if (error != null && context.mounted) {
      _notify(context, context.l10n.loadError, error);
    }
  }

  Future<void> _addCategory(BuildContext context) => showAppBottomSheet<void>(
    context: context,
    builder: (_) => CategoryFormSheet(
      onSubmit: (name, desc) => controller.createCategory(name, desc),
    ),
  );

  Future<void> _editCategory(BuildContext context, Category c) =>
      showAppBottomSheet<void>(
        context: context,
        builder: (_) => CategoryFormSheet(
          title: context.l10n.editCategory,
          initialName: c.name,
          initialDescription: c.description ?? '',
          onSubmit: (name, desc) =>
              controller.updateCategory(c.id, name: name, description: desc),
        ),
      );

  Future<void> _addMerchant(BuildContext context, Category c) =>
      showAppBottomSheet<void>(
        context: context,
        builder: (_) => MerchantFormSheet(
          categories: controller.categories.toList(),
          initialCategoryId: c.id,
          onSubmit: (name, keywords, categoryId) => controller.createMerchant(
            name: name,
            categoryId: categoryId,
            keywords: keywords,
          ),
        ),
      );

  Future<void> _editMerchant(BuildContext context, Merchant m) =>
      showAppBottomSheet<void>(
        context: context,
        builder: (_) => MerchantFormSheet(
          title: context.l10n.editMerchant,
          categories: controller.categories.toList(),
          initialName: m.name,
          initialKeywords: m.keywords,
          initialCategoryId: m.categoryId,
          onSubmit: (name, keywords, categoryId) => controller.updateMerchant(
            m.id,
            name: name,
            keywords: keywords,
            categoryId: categoryId,
          ),
          onDelete: () => controller.deleteMerchant(m.id),
        ),
      );

  Future<bool> _confirm(BuildContext context, String title, String body) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            key: const Key('confirm-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const Key('confirm-delete'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteCategory(BuildContext context, Category c) async {
    final l10n = context.l10n;
    if (!await _confirm(
      context,
      l10n.deleteCategoryTitle,
      l10n.deleteCategoryBody(c.name),
    )) {
      return;
    }
    final result = await controller.deleteCategory(c.id);
    if (!context.mounted) return;
    switch (result) {
      case CategoryDeleted():
        break;
      case CategoryDeleteFailed(:final message):
        _notify(context, l10n.loadError, message);
      case CategoryInUse(:final merchants, :final cardRules):
        await _reassignAndDelete(context, c, merchants, cardRules);
    }
  }

  Future<void> _reassignAndDelete(
    BuildContext context,
    Category c,
    int merchants,
    int rules,
  ) async {
    final l10n = context.l10n;
    final others = controller.categories.where((o) => o.id != c.id).toList();
    if (others.isEmpty) {
      _notify(context, l10n.errCategoryInUse, l10n.needOtherCategory);
      return;
    }
    final target = await showDialog<String>(
      context: context,
      builder: (_) => CategoryReassignDialog(
        others: others,
        message: l10n.reassignBody(
          l10n.merchantCount(merchants),
          l10n.ruleCountPlain(rules),
        ),
      ),
    );
    if (target == null || !context.mounted) return;
    final result = await controller.deleteCategory(c.id, reassignTo: target);
    if (result is CategoryDeleteFailed && context.mounted) {
      _notify(context, l10n.loadError, result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final tags = _tags(context);
      return CatalogView(
        categories: controller.categories.toList(),
        merchantsOf: controller.merchantsOf,
        ruleTagsOf: (id) => tags[id] ?? const [],
        loading: controller.loading.value || !controller.loaded.value,
        offline: controller.offline.value,
        errorMessage: controller.errorMessage.value,
        onRefresh: controller.load,
        onAddCategory: () => _addCategory(context),
        onQuickAddCategory: (name) => _quickAdd(context, name),
        onEditCategory: (c) => _editCategory(context, c),
        onDeleteCategory: (c) => _deleteCategory(context, c),
        onAddMerchant: (c) => _addMerchant(context, c),
        onEditMerchant: (m) => _editMerchant(context, m),
      );
    });
  }
}
