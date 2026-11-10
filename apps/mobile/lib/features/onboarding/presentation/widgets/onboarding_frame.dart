import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';

/// Common layout of a setup step: progress header ("Step N of 5" + Back),
/// scrolling content and a fixed footer with the actions.
class OnboardingFrame extends StatelessWidget {
  const OnboardingFrame({
    super.key,
    required this.child,
    this.step,
    this.stepName,
    this.onBack,
    this.trailing,
    this.footer,
  });

  /// 1-based step number; null hides the header.
  final int? step;
  final String? stepName;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (step != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.screen,
                0,
              ),
              child: StepProgress(
                step: step!,
                stepName: stepName,
                onBack: onBack,
                trailing: trailing,
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.md,
                AppSpacing.screen,
                AppSpacing.screen,
              ),
              child: child,
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.md,
                AppSpacing.screen,
                AppSpacing.xxl,
              ),
              child: footer,
            ),
        ],
      ),
    );
  }
}

/// Screen title (Bodoni) with an optional subtitle, entering from below.
class OnboardingTitle extends StatelessWidget {
  const OnboardingTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.gap = AppSpacing.sm,
  });

  final String title;

  /// Space between the title and the subtitle.
  final double gap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      from: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.headlineLarge),
          ),
          if (subtitle != null) ...[
            SizedBox(height: gap),
            Text(
              subtitle!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Selectable row (`.opt`): radio or checkbox marker, label and an optional
/// trailing widget. Selected rows get a 2 px primary border.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.checkbox = false,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool checkbox;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final marker = checkbox
        ? Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: selected ? scheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: 2,
              ),
            ),
            child: selected
                ? Icon(Icons.check_rounded, size: 15, color: scheme.onPrimary)
                : null,
          )
        : Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 7 : 2,
              ),
            ),
          );
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: !checkbox,
      child: Material(
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  marker,
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
