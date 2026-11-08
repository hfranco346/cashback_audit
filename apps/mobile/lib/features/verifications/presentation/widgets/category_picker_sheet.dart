import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../categories/domain/catalog_entities.dart';
import '../../domain/verification_entities.dart';

/// Bottom sheet to change the category of one statement line. Pops with the
/// chosen [Category], or with [CategoryPickerSheet.none] to clear it.
class CategoryPickerSheet extends StatelessWidget {
  const CategoryPickerSheet({
    super.key,
    required this.transaction,
    required this.categories,
    required this.onPick,
  });

  final VerificationTransaction transaction;
  final List<Category> categories;

  /// Receives the new category id, or `null` to clear the category.
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                S.changeCategoryTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                transaction.merchant,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in categories)
                    ListTile(
                      key: Key('pick-${c.id}'),
                      title: Text(c.name),
                      trailing: transaction.categoryId == c.id
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () => onPick(c.id),
                    ),
                  ListTile(
                    key: const Key('pick-none'),
                    leading: const Icon(Icons.block_rounded),
                    title: const Text(S.noCategoryOption),
                    trailing: transaction.categoryId == null
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () => onPick(null),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
