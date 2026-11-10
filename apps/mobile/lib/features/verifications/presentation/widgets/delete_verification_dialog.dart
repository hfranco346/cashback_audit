import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';

/// Overflow-menu entry value for "delete this check".
const deleteVerificationMenuValue = 'delete';

/// Confirmation before deleting a check: permanent, and (unless
/// [creditLost] is false) the check used is not returned. Resolves true when
/// the user confirms.
Future<bool> confirmDeleteVerification(
  BuildContext context, {
  required bool creditLost,
}) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const Key('delete-verification-dialog'),
      title: Text(l10n.deleteVerification),
      content: Text(
        creditLost
            ? '${l10n.deleteVerificationBody} ${l10n.deleteVerificationCreditNote}'
            : l10n.deleteVerificationBody,
      ),
      actions: [
        TextButton(
          key: const Key('delete-verification-cancel'),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('delete-verification-confirm'),
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            minimumSize: const Size(100, 44),
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
          ),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return ok == true;
}

/// The ⋮ menu with the single destructive entry, shared by the screens of
/// one verification.
class DeleteVerificationMenu extends StatelessWidget {
  const DeleteVerificationMenu({super.key, required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final error = Theme.of(context).colorScheme.error;
    return PopupMenuButton<String>(
      key: const Key('verification-menu'),
      tooltip: l10n.moreOptions,
      onSelected: (_) => onDelete(),
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          key: const Key('verification-menu-delete'),
          value: deleteVerificationMenuValue,
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: error),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  l10n.deleteVerification,
                  style: TextStyle(color: error, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
