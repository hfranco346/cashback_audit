import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../shared/widgets/atoms/app_logo_mark.dart';
import '../../../../shared/widgets/molecules/inline_message.dart';
import '../../../../shared/widgets/molecules/social_sign_in_button.dart';
import '../login_controller.dart';

/// Pure presentational login screen.
class LoginView extends StatelessWidget {
  const LoginView({
    super.key,
    required this.onGoogle,
    required this.onApple,
    required this.showApple,
    this.onDevSignIn,
    this.loading,
    this.errorMessage,
  });

  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final bool showApple;

  /// Debug builds only: signs in as the local test user.
  final VoidCallback? onDevSignIn;
  final LoginProvider? loading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = loading != null;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),
              const AppLogoMark(size: 64),
              const SizedBox(height: 28),
              FadeInUp(
                child: Text(S.loginTitle, style: theme.textTheme.displaySmall),
              ),
              const SizedBox(height: 12),
              FadeInUp(
                delay: const Duration(milliseconds: 120),
                child: Text(
                  S.loginSubtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Spacer(flex: 3),
              if (errorMessage != null) ...[
                FadeIn(child: InlineMessage(message: errorMessage!)),
                const SizedBox(height: 16),
              ],
              FadeInUp(
                delay: const Duration(milliseconds: 250),
                child: SocialSignInButton(
                  label: S.signInGoogle,
                  icon: Icons.g_mobiledata_rounded,
                  busy: loading == LoginProvider.google,
                  onPressed: busy ? null : onGoogle,
                ),
              ),
              if (showApple) ...[
                const SizedBox(height: 12),
                FadeInUp(
                  delay: const Duration(milliseconds: 350),
                  child: SocialSignInButton(
                    label: S.signInApple,
                    icon: Icons.apple_rounded,
                    dark: true,
                    busy: loading == LoginProvider.apple,
                    onPressed: busy ? null : onApple,
                  ),
                ),
              ],
              if (onDevSignIn != null) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  key: const Key('dev-sign-in'),
                  onPressed: busy ? null : onDevSignIn,
                  icon: const Icon(Icons.developer_mode_rounded),
                  label: const Text(S.devSignIn),
                ),
              ],
              const SizedBox(height: 20),
              Center(
                child: Text(
                  S.loginLegal,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
