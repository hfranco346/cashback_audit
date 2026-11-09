import 'package:flutter/material.dart';

/// Field wrapper from the design (`.f`): a bold 13 px label above [child]
/// and an optional 12 px help line below. [optionalTag] renders muted text
/// next to the label, e.g. `(optional)`.
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.label,
    required this.child,
    this.help,
    this.optionalTag,
  });

  final String label;
  final Widget child;
  final String? help;
  final String? optionalTag;

  /// Decoration for inputs inside an [AppField]: no floating label, 52 px
  /// minimum height.
  static InputDecoration decoration({
    String? hint,
    String? suffix,
    String? prefix,
  }) => InputDecoration(
    hintText: hint,
    suffixText: suffix,
    prefixText: prefix,
    counterText: '',
    isDense: false,
    constraints: const BoxConstraints(minHeight: 52),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (optionalTag != null)
                TextSpan(
                  text: ' $optionalTag',
                  style: TextStyle(color: muted, fontWeight: FontWeight.w500),
                ),
            ],
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        child,
        if (help != null) ...[
          const SizedBox(height: 6),
          Text(
            help!,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              height: 1.4,
              color: muted,
            ),
          ),
        ],
      ],
    );
  }
}
