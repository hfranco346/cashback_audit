import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../settings/domain/locale_preference.dart';
import '../../../settings/presentation/locale_controller.dart';

/// Step 2: the animated demo. The statement total opens into purchases and
/// ends in a verdict. Language selector on top (calls
/// [LocaleController.select]).
class DemoStep extends StatelessWidget {
  const DemoStep({
    super.key,
    required this.locale,
    required this.onStart,
    required this.onHaveAccount,
  });

  final LocaleController locale;
  final VoidCallback onStart;
  final VoidCallback onHaveAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.appColors;
    final muted = theme.colorScheme.onSurfaceVariant;
    final figures = theme.textTheme.bodyMedium?.copyWith(
      fontFeatures: appFigures,
      fontWeight: FontWeight.w700,
    );
    Widget line(Widget pill, String amount, {Color? color, int delay = 0}) =>
        FadeInUp(
          delay: Duration(milliseconds: delay),
          from: 14,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: pill),
              Text(amount, style: figures?.copyWith(color: color ?? muted)),
            ],
          ),
        );
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.sm,
              0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: LanguageMenu(controller: locale)),
                Flexible(
                  child: TextButton(
                    key: const Key('onb-have-account'),
                    onPressed: onHaveAccount,
                    child: Text(
                      l10n.onbHaveAccount,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInUp(
                    from: 14,
                    child: Text(
                      l10n.onbDemoTitle,
                      style: theme.textTheme.displaySmall,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FadeInUp(
                    delay: const Duration(milliseconds: 300),
                    from: 14,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    l10n.onbDemoStatementSays.toUpperCase(),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: muted,
                                    ),
                                  ),
                                ),
                                Text(
                                  'HNL 0.00',
                                  style: figures?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Divider(
                              color: theme.colorScheme.outlineVariant,
                              height: 1,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            line(
                              const StatusPill(
                                kind: StatusKind.ok,
                                label: 'Del Corral · 7%',
                              ),
                              '+HNL 79.84',
                              color: colors.success.fg,
                              delay: 700,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            line(
                              StatusPill(
                                kind: StatusKind.ok,
                                label: l10n.onbDemoPharmacy,
                              ),
                              '+HNL 78.82',
                              color: colors.success.fg,
                              delay: 1100,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            line(
                              StatusPill(
                                kind: StatusKind.neutral,
                                label: l10n.onbDemoPayment,
                              ),
                              '—',
                              delay: 1300,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            FadeInUp(
                              delay: const Duration(milliseconds: 1500),
                              from: 14,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: colors.error.bg,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          l10n.onbDemoOwed,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                color: colors.error.fg,
                                              ),
                                        ),
                                      ),
                                      Text(
                                        'HNL 1,526.84',
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              color: colors.error.fg,
                                              fontFeatures: appFigures,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FadeIn(
                    delay: const Duration(milliseconds: 1700),
                    child: Text(
                      l10n.onbDemoSub,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: muted,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.md,
              AppSpacing.screen,
              AppSpacing.xxl,
            ),
            child: Column(
              children: [
                AppButton(
                  key: const Key('onb-start'),
                  label: l10n.onbDemoCta,
                  onPressed: onStart,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.onbDemoFoot,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill-shaped language selector (Automatic / Español / English).
class LanguageMenu extends StatelessWidget {
  const LanguageMenu({super.key, required this.controller});

  final LocaleController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    String name(LocalePreference p) => switch (p) {
      LocalePreference.auto => l10n.languageAutomatic,
      LocalePreference.es => l10n.languageSpanish,
      LocalePreference.en => l10n.languageEnglish,
    };
    return Obx(() {
      final current = controller.locale.languageCode == 'en'
          ? l10n.languageEnglish
          : l10n.languageSpanish;
      return PopupMenuButton<LocalePreference>(
        key: const Key('onb-language'),
        position: PopupMenuPosition.under,
        tooltip: l10n.onbLangAria(current),
        onSelected: controller.select,
        itemBuilder: (_) => [
          for (final p in LocalePreference.values)
            CheckedPopupMenuItem(
              value: p,
              key: Key('onb-language-${p.name}'),
              checked: controller.preference.value == p,
              child: Text(name(p)),
            ),
        ],
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language_rounded, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  current,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(fontSize: 13),
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.expand_more_rounded, size: 16),
            ],
          ),
        ),
      );
    });
  }
}
