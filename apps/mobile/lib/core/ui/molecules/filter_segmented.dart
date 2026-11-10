import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class FilterOption<T> {
  const FilterOption({
    required this.value,
    required this.label,
    required this.count,
    this.key,
  });

  /// Key of the tappable segment (tests, analytics).
  final Key? key;

  final T value;
  final String label;
  final int count;
}

/// Pill-shaped segmented filter with a counter under each label. Options
/// share the width equally (no scrolling), so keep labels short.
class FilterSegmented<T> extends StatelessWidget {
  const FilterSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<FilterOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: scheme.outlineVariant),
      ),
      // A clipping Material (not ClipRRect): Ink paints on the nearest
      // Material, so only this keeps the selected fill inside the pill.
      child: Material(
        type: MaterialType.transparency,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(AppRadii.pill - 1),
        child: IntrinsicHeight(
          child: Row(
            children: [
              for (var i = 0; i < options.length; i++)
                Expanded(
                  child: _Segment(
                    option: options[i],
                    selected: options[i].value == selected,
                    first: i == 0,
                    onTap: () => onChanged(options[i].value),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.option,
    required this.selected,
    required this.first,
    required this.onTap,
  });

  final FilterOption<T> option;
  final bool selected;
  final bool first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: option.key,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : null,
            border: first
                ? null
                : Border(left: BorderSide(color: scheme.outlineVariant)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: fg,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                Text(
                  '${option.count}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected ? fg : scheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFeatures: appFigures,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
