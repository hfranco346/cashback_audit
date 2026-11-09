import 'package:flutter/material.dart';

import '../../l10n/l10n_context.dart';
import '../../theme/app_theme.dart';

/// Onboarding header: back button, "Step N of 5" and a progress bar. Back is
/// always visible (disabled on the first step when [onBack] is null).
class StepProgress extends StatelessWidget {
  const StepProgress({
    super.key,
    required this.step,
    this.total = 5,
    this.onBack,
    this.stepName,
    this.trailing,
  });

  final int step;
  final int total;
  final VoidCallback? onBack;

  /// Name shown after the number ("Step 2 of 5 · Your card").
  final String? stepName;

  /// Optional action next to the counter (e.g. "Skip").
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(l10n.back),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                stepName == null
                    ? l10n.stepOf(step, total)
                    : l10n.onbStepLabel(step, total, stepName!),
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: appFigures,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: (step / total).clamp(0, 1)),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (_, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 4,
              backgroundColor: theme.colorScheme.outlineVariant,
            ),
          ),
        ),
      ],
    );
  }
}
