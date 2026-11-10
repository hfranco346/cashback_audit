import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';

/// Pure presentational shell of the card Stepper: "Step N of 4" progress,
/// tappable step tabs, the current step ([child]) with a directional
/// transition, and a pinned Back / Next (or Save) footer.
class CardFormView extends StatelessWidget {
  const CardFormView({
    super.key,
    required this.step,
    required this.stepCount,
    required this.canJumpTo,
    required this.onJump,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
    required this.submitting,
    required this.forward,
    required this.child,
  });

  /// Current step, 0-based.
  final int step;
  final int stepCount;
  final bool Function(int step) canJumpTo;
  final ValueChanged<int> onJump;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSubmit;
  final bool submitting;

  /// Direction of the last move, for the transition.
  final bool forward;

  /// Content of the current step.
  final Widget child;

  bool get _isLast => step == stepCount - 1;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final labels = [
      l10n.cardStepTabCard,
      l10n.cardStepTabReward,
      l10n.cardStepTabRules,
      l10n.cardStepTabReview,
    ];
    final content = KeyedSubtree(key: ValueKey(step), child: child);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StepProgress(
                key: const Key('step-progress'),
                step: step + 1,
                total: stepCount,
                showBack: false,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 0; i < stepCount; i++)
                    Expanded(
                      child: _StepTab(
                        key: Key('step-tab-$i'),
                        index: i,
                        label: labels[i],
                        current: i == step,
                        done: i < step,
                        enabled: canJumpTo(i),
                        onTap: () => onJump(i),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: forward
              ? FadeInRight(
                  key: ValueKey('in-r-$step'),
                  from: 24,
                  duration: const Duration(milliseconds: 260),
                  child: content,
                )
              : FadeInLeft(
                  key: ValueKey('in-l-$step'),
                  from: 24,
                  duration: const Duration(milliseconds: 260),
                  child: content,
                ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: AppButton.ghost(
                      key: const Key('step-back'),
                      label: l10n.back,
                      icon: Icons.arrow_back_rounded,
                      onPressed: step == 0 || submitting ? null : onBack,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: _isLast
                        ? AppButton(
                            key: const Key('submit-card'),
                            label: l10n.save,
                            loading: submitting,
                            onPressed: submitting ? null : onSubmit,
                          )
                        : AppButton(
                            key: const Key('step-next'),
                            label: l10n.continueLabel,
                            onPressed: onNext,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One tab of the stepper header: a numbered dot (check once passed) and a
/// short label. Tappable only when [enabled].
class _StepTab extends StatelessWidget {
  const _StepTab({
    super.key,
    required this.index,
    required this.label,
    required this.current,
    required this.done,
    required this.enabled,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool current;
  final bool done;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = current || done;
    final dotColor = active ? scheme.primary : scheme.surfaceContainerHighest;
    final onDot = active ? scheme.onPrimary : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: current,
      enabled: enabled,
      label: label,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadii.field),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
                child: done
                    ? Icon(Icons.check_rounded, size: 16, color: onDot)
                    : Text(
                        '${index + 1}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: onDot,
                          fontWeight: FontWeight.w800,
                          fontFeatures: appFigures,
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                  color: enabled || current
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
