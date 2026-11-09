import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Meaning of a status. The tone comes from [AppStatusColors]; always show it
/// with an icon and text, never color alone.
enum StatusKind {
  /// Paid right / counted in a category (`ok`).
  ok,

  /// Underpaid / no category (`er`).
  error,

  /// Overpaid (`ov`).
  overpaid,

  /// Notice (`wn`).
  warning,

  /// Excluded (`nt`).
  neutral;

  StatusTone tone(AppStatusColors colors) => switch (this) {
    StatusKind.ok => colors.success,
    StatusKind.error => colors.error,
    StatusKind.overpaid => colors.overpaid,
    StatusKind.warning => colors.warning,
    StatusKind.neutral => colors.neutral,
  };

  IconData get icon => switch (this) {
    StatusKind.ok => Icons.check_rounded,
    StatusKind.error => Icons.priority_high_rounded,
    StatusKind.overpaid => Icons.arrow_upward_rounded,
    StatusKind.warning => Icons.warning_amber_rounded,
    StatusKind.neutral => Icons.remove_rounded,
  };
}

/// Small rounded label: status icon + text on the status background (`.pill`).
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.kind,
    required this.label,
    this.icon,
  });

  final StatusKind kind;
  final String label;

  /// Overrides the default icon of [kind].
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tone = kind.tone(context.appColors);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? kind.icon, size: 13, color: tone.fg),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: tone.fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round 28 px status marker with only an icon (`.pill` as a dot). Pass
/// [semanticLabel] so the meaning is not conveyed by color alone.
class StatusDot extends StatelessWidget {
  const StatusDot({
    super.key,
    required this.kind,
    this.icon,
    this.semanticLabel,
    this.size = 28,
  });

  final StatusKind kind;
  final IconData? icon;
  final String? semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tone = kind.tone(context.appColors);
    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: tone.bg, shape: BoxShape.circle),
        child: Icon(icon ?? kind.icon, size: size / 2, color: tone.fg),
      ),
    );
  }
}
