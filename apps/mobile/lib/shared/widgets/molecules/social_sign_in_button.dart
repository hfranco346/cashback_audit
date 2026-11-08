import 'package:flutter/material.dart';

/// Full-width provider button with an inline spinner while [busy].
class SocialSignInButton extends StatelessWidget {
  const SocialSignInButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
    this.dark = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;

  /// Inverted style (used for Apple's black button).
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = dark ? scheme.surface : scheme.onSurface;
    final bg = dark ? scheme.onSurface : scheme.surface;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: 0.7),
          disabledForegroundColor: fg.withValues(alpha: 0.7),
          side: dark ? null : BorderSide(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            else
              Icon(icon, size: 22),
            const SizedBox(width: 12),
            Text(label),
          ],
        ),
      ),
    );
  }
}
