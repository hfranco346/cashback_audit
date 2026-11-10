import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../login_controller.dart';

/// Pure presentational login screen (reached when the guided setup is
/// skipped or the user already has an account).
class LoginView extends StatelessWidget {
  const LoginView({
    super.key,
    required this.emailSection,
    required this.onGoogle,
    required this.onApple,
    required this.showApple,
    this.showGoogle = true,
    this.showAlternatives = true,
    this.onDevSignIn,
    this.loading,
    this.errorMessage,
  });

  /// The email / code forms (the primary way in).
  final Widget emailSection;
  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final bool showApple;
  final bool showGoogle;

  /// Google / Apple / dev buttons; hidden while the code is being entered.
  final bool showAlternatives;

  /// Debug builds only: signs in as the local test user.
  final VoidCallback? onDevSignIn;
  final LoginProvider? loading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.appColors;
    final busy = loading != null;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screen,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.xxl),
                    const Spacer(flex: 2),
                    ZoomIn(
                      child: Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.creditCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFCDAE6E)
                                .withValues(alpha: 0.8),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          'C',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: colors.onCreditCard,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FadeInUp(
                      from: 14,
                      child: Text(
                        l10n.loginTitle,
                        style: theme.textTheme.displaySmall,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FadeInUp(
                      from: 14,
                      delay: const Duration(milliseconds: 120),
                      child: Text(
                        l10n.loginSubtitle,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const Spacer(flex: 3),
                    const SizedBox(height: AppSpacing.xxl),
                    if (errorMessage != null) ...[
                      FadeIn(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 18,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    FadeInUp(from: 14, child: emailSection),
                    if (showAlternatives) ...[
                      if (showApple || showGoogle) ...[
                        const SizedBox(height: AppSpacing.lg),
                        OrDivider(label: l10n.emailOrContinueWith),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (showApple) ...[
                        FilledButton.icon(
                          key: const Key('login-apple'),
                          onPressed: busy ? null : onApple,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52),
                            backgroundColor: theme.colorScheme.onSurface,
                            foregroundColor: theme.colorScheme.surface,
                          ),
                          icon: loading == LoginProvider.apple
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                  ),
                                )
                              : const Icon(Icons.apple_rounded, size: 20),
                          label: Text(l10n.signInApple),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (showGoogle)
                        AppButton.ghost(
                          key: const Key('login-google'),
                          label: l10n.signInGoogle,
                          icon: Icons.g_mobiledata_rounded,
                          loading: loading == LoginProvider.google,
                          onPressed: busy ? null : onGoogle,
                        ),
                      if (onDevSignIn != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Center(
                          child: TextButton.icon(
                            key: const Key('dev-sign-in'),
                            onPressed: busy ? null : onDevSignIn,
                            icon: const Icon(Icons.developer_mode_rounded),
                            label: Text(l10n.devSignIn),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    Center(
                      child: Text(
                        l10n.loginLegal,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hairline rule with a centered label ("or continue with").
class OrDivider extends StatelessWidget {
  const OrDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = Expanded(
      child: Divider(color: theme.colorScheme.outlineVariant, height: 1),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        line,
      ],
    );
  }
}
