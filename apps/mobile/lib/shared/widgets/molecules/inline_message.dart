import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

enum InlineMessageTone { error, warning, info }

/// Compact banner for errors, warnings and notices.
class InlineMessage extends StatelessWidget {
  const InlineMessage({
    super.key,
    required this.message,
    this.tone = InlineMessageTone.error,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final InlineMessageTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final verdicts = context.verdictColors;
    final (bg, fg, icon) = switch (tone) {
      InlineMessageTone.error => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.error_outline_rounded,
      ),
      InlineMessageTone.warning => (
        verdicts.warningContainer,
        verdicts.warning,
        Icons.warning_amber_rounded,
      ),
      InlineMessageTone.info => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.info_outline_rounded,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: fg),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: fg),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
