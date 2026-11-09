import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/decimal_utils.dart';
import '../../domain/verification_entities.dart';

/// "Your bank mentions 2 categories you don't have": one tickable row per
/// statement category the user lacks and the free action to create them.
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
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (suggestions.isEmpty) {
      return createdNotice
          ? InlineNotice(
              key: const Key('suggestions-created'),
              message: l10n.suggestionsCreated,
              kind: StatusKind.ok,
            )
          : const SizedBox.shrink();
    }
    final onTone = scheme.onPrimaryContainer;
    return Card(
      key: const Key('suggested-categories-card'),
      color: scheme.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: onTone),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.suggestionsTitleN(suggestions.length),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: onTone,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              for (final s in suggestions)
                _SuggestionRow(
                  key: Key('suggestion-${s.name}'),
                  suggestion: s,
                  checked: selected.contains(s.name),
                  enabled: !creating,
                  onChanged: (v) => onToggle(s.name, v),
                ),
              const SizedBox(height: 6),
              FilledButton(
                key: const Key('create-suggestions'),
                onPressed: selected.isEmpty || creating ? null : onCreate,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                child: creating
                    ? Text(l10n.creatingSuggestions)
                    : Text(l10n.createNSuggestions(selected.length)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    super.key,
    required this.suggestion,
    required this.checked,
    required this.enabled,
    required this.onChanged,
  });

  final SuggestedCategory suggestion;
  final bool checked;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onTone = scheme.onPrimaryContainer;
    return Semantics(
      checked: checked,
      inMutuallyExclusiveGroup: false,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? () => onChanged(!checked) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: checked ? scheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: scheme.primary, width: 2),
                ),
                child: checked
                    ? Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: scheme.onPrimary,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  suggestion.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: onTone,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (suggestion.ratePercent != null) ...[
                const SizedBox(width: 8),
                Text(
                  formatRate(suggestion.ratePercent!),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: onTone,
                    fontWeight: FontWeight.w800,
                    fontFeatures: appFigures,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Text(
                l10n.suggestionTxns(suggestion.matchingTransactionCount),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: onTone.withValues(alpha: 0.8),
                  fontFeatures: appFigures,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
