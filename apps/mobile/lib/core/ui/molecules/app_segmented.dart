import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class SegmentOption<T> {
  const SegmentOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Equal-width pill segmented control (`.seg`): the selected segment fills
/// with the primary container and shows a check, so the state is never color
/// alone.
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<SegmentOption<T>> options;
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.pill - 1),
        child: Row(
          children: [
            for (var i = 0; i < options.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: options[i].value == selected,
                  child: InkWell(
                    onTap: () => onChanged(options[i].value),
                    child: Ink(
                      decoration: BoxDecoration(
                        color: options[i].value == selected
                            ? scheme.primaryContainer
                            : null,
                        border: i == 0
                            ? null
                            : Border(
                                left: BorderSide(color: scheme.outlineVariant),
                              ),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (options[i].value == selected) ...[
                              Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: scheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                options[i].label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: options[i].value == selected
                                      ? scheme.onPrimaryContainer
                                      : scheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
