import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../email_sign_in_controller.dart';

/// Localized copy for an [EmailIssue].
String emailIssueText(AppLocalizations l10n, EmailIssue issue) {
  switch (issue.kind) {
    case EmailIssueKind.invalidEmail:
      return l10n.emailInvalid;
    case EmailIssueKind.invalidCode:
      final left = issue.attemptsLeft;
      return left == null || left < 0
          ? l10n.emailCodeInvalid
          : l10n.emailCodeInvalidLeft(left);
    case EmailIssueKind.codeExpired:
      return l10n.emailCodeExpired;
    case EmailIssueKind.tooManyAttempts:
      return l10n.emailCodeTooManyAttempts;
    case EmailIssueKind.rateLimited:
      final seconds = issue.seconds;
      return seconds == null || seconds <= 0
          ? issue.message ?? l10n.emailInvalid
          : l10n.emailRateLimited(seconds);
    case EmailIssueKind.other:
      return issue.message ?? '';
  }
}

class _IssueText extends StatelessWidget {
  const _IssueText({required this.issue});

  final EmailIssue issue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
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
            emailIssueText(context.l10n, issue),
            key: const Key('email-issue'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// First step: the email field and the "Send code" action.
class EmailAddressForm extends StatelessWidget {
  const EmailAddressForm({
    super.key,
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onChanged,
    this.blockedSeconds = 0,
    this.issue,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback? onSend;
  final ValueChanged<String> onChanged;

  /// Seconds before a code can be requested again for this address.
  final int blockedSeconds;
  final EmailIssue? issue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final blocked = blockedSeconds > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppField(
          label: l10n.emailFieldLabel,
          child: TextField(
            key: const Key('email-field'),
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            enableSuggestions: false,
            onChanged: onChanged,
            onSubmitted: (_) => onSend?.call(),
            decoration: AppField.decoration(hint: l10n.emailFieldHint),
          ),
        ),
        if (issue != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _IssueText(issue: issue!),
        ],
        const SizedBox(height: AppSpacing.md),
        AppButton(
          key: const Key('email-send'),
          label: blocked
              ? l10n.emailRetryIn(blockedSeconds)
              : l10n.emailSendCode,
          loading: sending,
          onPressed: blocked ? null : onSend,
        ),
      ],
    );
  }
}

/// Second step: the 6-digit code field, with resend and "change email".
class EmailCodeForm extends StatelessWidget {
  const EmailCodeForm({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.email,
    required this.expiryMinutes,
    required this.resendIn,
    required this.verifying,
    required this.sending,
    required this.onChanged,
    required this.onResend,
    required this.onChangeEmail,
    this.issue,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String email;
  final int expiryMinutes;
  final int resendIn;
  final bool verifying;
  final bool sending;
  final EmailIssue? issue;
  final ValueChanged<String> onChanged;
  final VoidCallback onResend;
  final VoidCallback onChangeEmail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.emailCodeTitle, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.emailCodeSent(email),
          key: const Key('email-sent-to'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: muted,
            height: 1.4,
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const Key('email-change'),
            onPressed: verifying ? null : onChangeEmail,
            child: Text(l10n.emailChange),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppField(
          label: l10n.emailCodeLabel,
          child: TextField(
            key: const Key('email-code-field'),
            controller: controller,
            focusNode: focusNode,
            enabled: !verifying,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              letterSpacing: 10,
              fontFeatures: appFigures,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(
                EmailSignInController.codeLength,
              ),
            ],
            onChanged: onChanged,
            decoration: AppField.decoration(hint: '······'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (verifying)
          Row(
            children: [
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.emailVerifying, style: theme.textTheme.bodySmall),
            ],
          )
        else if (issue != null)
          _IssueText(issue: issue!)
        else
          Text(
            l10n.emailCodeExpiry(expiryMinutes),
            key: const Key('email-expiry-hint'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: muted,
              height: 1.4,
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        AppButton.ghost(
          key: const Key('email-resend'),
          label: resendIn > 0 ? l10n.emailResendIn(resendIn) : l10n.emailResend,
          loading: sending,
          onPressed: resendIn > 0 || verifying ? null : onResend,
        ),
      ],
    );
  }
}
