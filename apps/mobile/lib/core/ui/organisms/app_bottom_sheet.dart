import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Opens [builder] in a modal sheet with the app's 28 px radius, scroll
/// control and keyboard-aware padding. Wrap content in [AppBottomSheet].
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: builder,
);

/// Content scaffold for bottom sheets: title (Manrope 20), scrolling
/// body, and a pinned actions area. Presentational only.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.titleStyle,
    this.subtitleStyle,
    this.trailing,
    this.actionsPadding = const EdgeInsets.all(AppSpacing.screen),
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// Overrides of the default title / subtitle styles (Manrope 20 / body).
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  /// Shown at the end of the header row (e.g. an amount).
  final Widget? trailing;
  final EdgeInsetsGeometry actionsPadding;

  /// Buttons stacked under the body (primary first).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                4,
                AppSpacing.screen,
                AppSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            style:
                                titleStyle ??
                                theme.textTheme.titleLarge?.copyWith(
                                  fontSize: 20,
                                ),
                          ),
                        ),
                        if (subtitle != null) ...[
                          SizedBox(height: subtitleStyle == null ? 4 : 2),
                          Text(
                            subtitle!,
                            style:
                                subtitleStyle ??
                                theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: AppSpacing.md),
                    trailing!,
                  ],
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screen,
                ),
                child: child,
              ),
            ),
            if (actions.isNotEmpty)
              Padding(
                padding: actionsPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.sm),
                      actions[i],
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
