import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../email_sign_in_controller.dart';
import '../login_controller.dart';
import 'email_forms.dart';

/// Container that wires the email / code forms to [EmailSignInController].
/// Shared by the login screen and the setup's account step.
class EmailSignInSection extends StatelessWidget {
  const EmailSignInSection({
    super.key,
    required this.controller,
    required this.login,
  });

  final EmailSignInController controller;
  final LoginController login;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return AutofillGroup(
      child: Obx(() {
        final verifying = login.loading.value == LoginProvider.email;
        if (c.stage.value == EmailStage.code) {
          return EmailCodeForm(
            controller: c.codeText,
            focusNode: c.codeFocus,
            email: c.sentTo.value,
            expiryMinutes: c.expiryMinutes,
            resendIn: c.resendIn.value,
            verifying: verifying,
            sending: c.sending.value,
            issue: c.issue.value,
            onChanged: c.onCodeChanged,
            onResend: c.sendCode,
            onChangeEmail: c.changeEmail,
          );
        }
        return EmailAddressForm(
          controller: c.emailText,
          sending: c.sending.value,
          issue: c.issue.value,
          blockedSeconds: c.blockedSeconds,
          onChanged: c.onEmailChanged,
          onSend: login.isBusy ? null : c.sendCode,
        );
      }),
    );
  }
}
