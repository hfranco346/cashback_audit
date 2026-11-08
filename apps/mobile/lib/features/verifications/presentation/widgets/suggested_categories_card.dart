import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/decimal_utils.dart';
import '../../../../shared/widgets/molecules/inline_message.dart';
import '../../domain/verification_entities.dart';

/// "Tu estado de cuenta menciona rubros que no tienes": one checkbox per
/// statement category the user lacks, plus the (free) action to create them.
class SuggestedCategoriesCard extends StatelessWidget {
  const SuggestedCategoriesCard({
    super.key,
    required this.suggestions,
    required this.selected,
    required this.onToggle,
    required this.onCreate,
    required this.creating,
    required this.createdNotice,
  });

  final List<SuggestedCategory> suggestions;
  final Set<String> selected;
  final void Function(String name, bool selected) onToggle;
  final VoidCallback onCreate;
  final bool creating;

  /// Shown once categories were created (replaces the list when it is empty).
  final bool createdNotice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = context.statusColors;
    if (suggestions.isEmpty) {
      return createdNotice
          ? InlineMessage(
              key: const Key('suggestions-created'),
              message: S.suggestionsCreated,
              tone: InlineMessageTone.info,
            )
          : const SizedBox.shrink();
    }
    return Card(
      key: const Key('suggested-categories-card'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.playlist_add_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    S.suggestionsTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              S.suggestionsHelper,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            for (final s in suggestions)
              CheckboxListTile(
                key: Key('suggestion-${s.name}'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: selected.contains(s.name),
                onChanged: creating
                    ? null
                    : (v) => onToggle(s.name, v ?? false),
                title: Text(s.name),
                subtitle: Text(
                  [
                    if (s.ratePercent != null) formatRate(s.ratePercent!),
                    S.suggestionLines(s.matchingTransactionCount),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: s.matchingTransactionCount > 0
                        ? status.success
                        : theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              S.suggestionsFree,
              key: const Key('suggestions-free'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              key: const Key('create-suggestions'),
              onPressed: selected.isEmpty || creating ? null : onCreate,
              icon: creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(
                creating ? S.creatingSuggestions : S.createSuggestions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
