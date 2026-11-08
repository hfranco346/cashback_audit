import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/strings.dart';
import '../domain/catalog_entities.dart';
import 'catalog_controller.dart';
import 'widgets/catalog_view.dart';
import 'widgets/category_form_sheet.dart';
import 'widgets/merchant_form_sheet.dart';

/// Container for categories & merchants management.
class CatalogPage extends GetView<CatalogController> {
  const CatalogPage({super.key});

  Future<void> _sheet(Widget child) => Get.bottomSheet<void>(
    SafeArea(child: child),
    isScrollControlled: true,
    backgroundColor: Get.theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
  );

  void _addCategory() => _sheet(
    CategoryFormSheet(
      onSubmit: (name, desc) => controller.createCategory(name, desc),
    ),
  );

  void _editCategory(Category c) => _sheet(
    CategoryFormSheet(
      title: S.editCategory,
      initialName: c.name,
      initialDescription: c.description ?? '',
      onSubmit: (name, desc) =>
          controller.updateCategory(c.id, name: name, description: desc),
    ),
  );

  void _addMerchant(Category c) => _sheet(
    MerchantFormSheet(
      categories: controller.categories.toList(),
      initialCategoryId: c.id,
      onSubmit: (name, keywords, categoryId) => controller.createMerchant(
        name: name,
        categoryId: categoryId,
        keywords: keywords,
      ),
    ),
  );

  void _editMerchant(Merchant m) => _sheet(
    MerchantFormSheet(
      title: S.editMerchant,
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
    ),
  );

  Future<bool> _confirm(String title, String body) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Get.back<bool>(result: false),
            child: const Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Get.back<bool>(result: true),
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            child: const Text(S.delete),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteMerchant(Merchant m) async {
    if (!await _confirm(S.deleteMerchantTitle, S.deleteMerchantBody(m.name))) {
      return;
    }
    final error = await controller.deleteMerchant(m.id);
    if (error != null) Get.snackbar(S.loadError, error);
  }

  Future<void> _deleteCategory(Category c) async {
    if (!await _confirm(S.deleteCategoryTitle, S.deleteCategoryBody(c.name))) {
      return;
    }
    final result = await controller.deleteCategory(c.id);
    switch (result) {
      case CategoryDeleted():
        break;
      case CategoryDeleteFailed(:final message):
        Get.snackbar(S.loadError, message);
      case CategoryInUse(:final merchants, :final cardRules):
        await _reassignAndDelete(c, merchants, cardRules);
    }
  }

  Future<void> _reassignAndDelete(Category c, int merchants, int rules) async {
    final others = controller.categories.where((o) => o.id != c.id).toList();
    if (others.isEmpty) {
      Get.snackbar(S.errCategoryInUse, S.needOtherCategory);
      return;
    }
    final target = await Get.dialog<String>(
      _ReassignDialog(
        others: others,
        message: S.reassignBody(merchants, rules),
      ),
    );
    if (target == null) return;
    final result = await controller.deleteCategory(c.id, reassignTo: target);
    if (result is CategoryDeleteFailed) {
      Get.snackbar(S.loadError, result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => CatalogView(
        categories: controller.categories.toList(),
        merchantsOf: controller.merchantsOf,
        loading: controller.loading.value,
        offline: controller.offline.value,
        errorMessage: controller.errorMessage.value,
        onRefresh: controller.load,
        onAddCategory: _addCategory,
        onEditCategory: _editCategory,
        onDeleteCategory: _deleteCategory,
        onAddMerchant: _addMerchant,
        onEditMerchant: _editMerchant,
        onDeleteMerchant: _deleteMerchant,
      ),
    );
  }
}

class _ReassignDialog extends StatefulWidget {
  const _ReassignDialog({required this.others, required this.message});

  final List<Category> others;
  final String message;

  @override
  State<_ReassignDialog> createState() => _ReassignDialogState();
}

class _ReassignDialogState extends State<_ReassignDialog> {
  late String _target = widget.others.first.id;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(S.deleteCategoryTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _target,
            isExpanded: true,
            decoration: const InputDecoration(labelText: S.reassignTo),
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_target),
          style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
          child: const Text(S.reassignAndDelete),
        ),
      ],
    );
  }
}
