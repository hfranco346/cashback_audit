import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../auth/presentation/email_sign_in_controller.dart';
import '../../../auth/presentation/login_controller.dart';
import '../../../auth/presentation/widgets/email_sign_in_section.dart';
import '../../../auth/presentation/widgets/login_view.dart' show OrDivider;
import '../../../cards/domain/card_entities.dart';
import '../onboarding_controller.dart';
import 'onboarding_frame.dart';

/// Step 4: create the account (email code / Apple / Google / dev) once there is something
/// to save. After sign-in the draft is pushed to the backend.
class AccountStep extends StatelessWidget {
  const AccountStep({
    super.key,
    required this.controller,
    required this.login,
    required this.email,
  });

  final OnboardingController controller;
  final LoginController login;
  final EmailSignInController email;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = controller;
    final section = EmailSignInSection(controller: email, login: login);
    return Obx(() {
      // While the code is typed the form takes the whole step.
      final entering =
          email.stage.value == EmailStage.code &&
          !c.syncing.value &&
          c.syncError.value == null;
      return OnboardingFrame(
        step: 4,
        stepName: l10n.onbStepAccount,
        onBack: c.back,
        footer: entering ? null : _footer(context, section),
        child: entering ? section : _summary(context),
      );
    });
  }

  Widget _footer(BuildContext context, Widget section) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final c = controller;
    return Obx(() {
      if (c.syncing.value) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(l10n.onbSyncing),
          ],
        );
      }
      if (c.syncError.value != null) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              key: const Key('onb-retry-sync'),
              label: l10n.retry,
              onPressed: c.retrySync,
            ),
            AppButton.ghost(label: l10n.onbGoHome, onPressed: c.leaveToHome),
          ],
        );
      }
      final busy = login.loading.value != null;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          section,
          if (login.showApple || login.showGoogle) ...[
            const SizedBox(height: AppSpacing.md),
            OrDivider(label: l10n.emailOrContinueWith),
            const SizedBox(height: AppSpacing.md),
          ],
          if (login.errorMessage.value != null) ...[
            Text(
              login.errorMessage.value!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (login.showApple)
            FilledButton.icon(
              key: const Key('onb-apple'),
              onPressed: busy ? null : login.signInWithApple,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: theme.colorScheme.onSurface,
                foregroundColor: theme.colorScheme.surface,
              ),
              icon: login.loading.value == LoginProvider.apple
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Icon(Icons.apple_rounded, size: 20),
              label: Text(l10n.signInApple),
            ),
          if (login.showApple) const SizedBox(height: 10),
          if (login.showGoogle)
            AppButton.ghost(
              key: const Key('onb-google'),
              label: l10n.signInGoogle,
              icon: Icons.g_mobiledata_rounded,
              loading: login.loading.value == LoginProvider.google,
              onPressed: busy ? null : login.signInWithGoogle,
            ),
          if (login.showDevSignIn)
            TextButton.icon(
              key: const Key('dev-sign-in'),
              onPressed: busy ? null : login.signInForDevelopment,
              icon: const Icon(Icons.developer_mode_rounded),
              label: Text(l10n.devSignIn),
            ),
        ],
      );
    });
  }

  Widget _summary(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.appColors;
    final c = controller;
    return Obx(() {
      final d = c.draft.value;
      final unit = d.rewardUnit == RewardUnit.points
          ? l10n.onbRewardPoints.toLowerCase()
          : l10n.onbRewardCashback.toLowerCase();
      final selected = [
        for (final cat in d.categories) (name: cat.name, rate: cat.rate.trim()),
        (name: l10n.onbBaseTitle, rate: d.baseRate.trim()),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnboardingTitle(
            title: l10n.onbAccountTitle,
            subtitle: l10n.onbAccountSub,
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.creditCard,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: const Color(0xFFCDAE6E)
                                .withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${c.cardName} •••• ${d.last4}',
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              l10n.onbAccountCardSub(
                                d.bank,
                                unit,
                                d.currency ?? l10n.onbAccountCurrencyDetected,
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Divider(color: theme.colorScheme.outlineVariant, height: 1),
                  const SizedBox(height: AppSpacing.md),
                  for (final row in selected)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: colors.success.fg,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              row.name,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            row.rate.isEmpty ? '—' : '${row.rate}%',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontFeatures: appFigures,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 18, color: colors.brass),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.onbAccountPrivacy,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          if (c.syncError.value != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              '${l10n.onbSyncFailed}\n${c.syncError.value}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      );
    });
  }
}
