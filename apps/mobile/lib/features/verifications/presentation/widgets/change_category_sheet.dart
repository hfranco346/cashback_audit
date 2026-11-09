import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../categories/domain/catalog_entities.dart';
import '../../domain/verification_entities.dart';
import '../result_controller.dart' show displayMerchantName;

/// What the user picked in [ChangeCategorySheet].
class CategoryChoice {
  const CategoryChoice(this.categoryId, {required this.remember});

  /// `null` means "no category".
  final String? categoryId;
  final bool remember;
}

/// Opens the "Change category" sheet for [transaction]. Resolves to the
/// choice, or `null` when it was dismissed.
Future<CategoryChoice?> showChangeCategorySheet({
  required BuildContext context,
  required VerificationTransaction transaction,
  required List<Category> categories,
  required String amountText,
  required String baseRate,
  required String? Function(String categoryId) rateOf,
  required VoidCallback onGoToCategories,
}) => showAppBottomSheet<CategoryChoice>(
  context: context,
  builder: (_) => ChangeCategorySheet(
    transaction: transaction,
    categories: categories,
    amountText: amountText,
    baseRate: baseRate,
    rateOf: rateOf,
    onGoToCategories: onGoToCategories,
  ),
);

/// Bottom sheet to move one statement line to a category. A switch decides
/// whether the merchant is also remembered for the next verifications;
/// replaces the two confusing "assign" / "change" actions.
class ChangeCategorySheet extends StatefulWidget {
  const ChangeCategorySheet({
    super.key,
    required this.transaction,
    required this.categories,
    required this.amountText,
    required this.baseRate,
    required this.rateOf,
    required this.onGoToCategories,
  });

  final VerificationTransaction transaction;
  final List<Category> categories;
  final String amountText;

  /// `0%` style label of the card's base rate ("No category" option).
  final String baseRate;

  /// `7%` for categories the card has a rule for; `null` otherwise.
  final String? Function(String categoryId) rateOf;
  final VoidCallback onGoToCategories;

  @override
  State<ChangeCategorySheet> createState() => _ChangeCategorySheetState();
}

class _ChangeCategorySheetState extends State<ChangeCategorySheet> {
  static const _none = '__none__';
  String? _selected; // category id, [_none], or null = nothing chosen yet
  bool _remember = false;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    _selected = tx.categoryId;
    if (_selected == null && tx.suggestedHint != null) {
      final hint = tx.suggestedHint!.toLowerCase();
      for (final c in widget.categories) {
        if (c.name.toLowerCase() == hint) _selected = c.id;
      }
    }
  }

  bool get _canRemember => _selected != null && _selected != _none;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final tx = widget.transaction;
    final name = tx.matchedMerchantName ?? displayMerchantName(tx.merchant);
    final remember = _remember && _canRemember;
    return AppBottomSheet(
      title: name,
      subtitle: tx.merchant.toUpperCase() == name.toUpperCase()
          ? null
          : tx.merchant,
      actions: [
        AppButton(
          key: const Key('change-apply'),
          label: l10n.applyRecalcFree,
          onPressed: _selected == null
              ? null
              : () => Navigator.of(context).pop(
                  CategoryChoice(
                    _selected == _none ? null : _selected,
                    remember: remember,
                  ),
                ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              widget.amountText,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: appFigures,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (widget.categories.isEmpty) ...[
            InlineNotice(
              message: l10n.noCategoriesToAssign,
              kind: StatusKind.warning,
              actionLabel: l10n.goToCategories,
              onAction: () {
                Navigator.of(context).pop();
                widget.onGoToCategories();
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ] else ...[
            Text(
              l10n.changeSheetQuestion,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Semantics(
              container: true,
              child: Column(
                children: [
                  for (final c in widget.categories)
                    _Option(
                      key: Key('pick-${c.id}'),
                      label: c.name,
                      trailing: widget.rateOf(c.id) ?? l10n.changeSheetNoRate,
                      trailingIsRate: widget.rateOf(c.id) != null,
                      selected: _selected == c.id,
                      onTap: () => setState(() => _selected = c.id),
                    ),
                  _Option(
                    key: const Key('pick-none'),
                    label: l10n.noCategoryOption,
                    trailing: l10n.changeSheetBase(widget.baseRate),
                    trailingIsRate: true,
                    selected: _selected == _none,
                    onTap: () => setState(() => _selected = _none),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.rememberTitle,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            !_canRemember && _selected == _none
                                ? l10n.rememberNeedsCategory
                                : remember
                                ? l10n.rememberOn
                                : l10n.rememberOff,
                            key: const Key('remember-help'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      key: const Key('remember-switch'),
                      value: remember,
                      onChanged: _canRemember
                          ? (v) => setState(() => _remember = v)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    super.key,
    required this.label,
    required this.trailing,
    required this.trailingIsRate,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String trailing;
  final bool trailingIsRate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        inMutuallyExclusiveGroup: true,
        selected: selected,
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? scheme.primary
                              : scheme.outlineVariant,
                          width: selected ? 6 : 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      trailing,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: trailingIsRate ? 13 : 12,
                        fontFeatures: appFigures,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
