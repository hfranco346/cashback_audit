import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../atoms/status_pill.dart';

/// Inline message on a status background with its icon and an optional
/// action. Replaces the legacy `InlineMessage` and snackbars in redesigned
/// screens; meaning is never conveyed by color alone.
class InlineNotice extends StatelessWidget {
  const InlineNotice({
    super.key,
    required this.message,
    this.kind = StatusKind.error,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final StatusKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tone = kind.tone(context.appColors);
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: tone.fg,
      fontWeight: FontWeight.w600,
      fontSize: 13,
      height: 1.4,
    );
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: BorderRadius.circular(AppRadii.field),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(kind.icon, size: 18, color: tone.fg),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message, style: style),
                    if (actionLabel != null && onAction != null)
                      TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          foregroundColor: tone.fg,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(48, 40),
                          alignment: Alignment.centerLeft,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: style?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: Text(actionLabel!),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
