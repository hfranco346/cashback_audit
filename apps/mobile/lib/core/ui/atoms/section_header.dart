import 'package:flutter/material.dart';

/// Section title (Manrope 18/700) with an optional trailing action. With
/// [caption] it renders the small uppercase label (`.cap`) instead.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.caption = false,
  });

  final String title;
  final Widget? trailing;
  final bool caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = caption
        ? theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          )
        : theme.textTheme.titleLarge?.copyWith(fontSize: 18);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(caption ? title.toUpperCase() : title, style: style),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
