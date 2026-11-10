import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_messages.dart';
import '../domain/auth_repository.dart';
import 'login_controller.dart';

enum EmailStage { address, code }

enum EmailIssueKind {
  invalidEmail,
  invalidCode,
  codeExpired,
  tooManyAttempts,
  rateLimited,
  other,
}

/// Something the email / code forms must tell the user. The view turns it
/// into localized copy; [message] only carries the generic fallback text.
class EmailIssue {
  const EmailIssue(this.kind, {this.seconds, this.attemptsLeft, this.message});

  final EmailIssueKind kind;

  /// `retryAfterSeconds` of a rate limit.
  final int? seconds;

  /// Tries left after a wrong code, when the backend says.
  final int? attemptsLeft;
  final String? message;
}

/// State machine of the "sign in with an emailed code" flow:
/// address -> code -> signed in. Shared by the login screen and the setup's
/// account step; the session itself is started by [LoginController].
class EmailSignInController extends GetxController {
  EmailSignInController({
    required this._repository,
    required this._login,
    required this._localeCode,
  });

  static const codeLength = 6;
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final AuthRepository _repository;
  final LoginController _login;
  final String Function() _localeCode;

  final emailText = TextEditingController();
  final codeText = TextEditingController();
  final codeFocus = FocusNode();

  final stage = EmailStage.address.obs;
  final sending = false.obs;
  final issue = Rxn<EmailIssue>();

  /// Seconds until another code may be requested (0 = now).
  final resendIn = 0.obs;

  /// Seconds until the current code stops working.
  final expiresIn = 0.obs;

  /// Normalized address the code was sent to.
  final sentTo = ''.obs;

  Timer? _ticker;
  String _cooldownEmail = '';

  bool get verifying => _login.loading.value == LoginProvider.email;

  /// Whole minutes the code lasts, for the hint under the field.
  int get expiryMinutes => (_expiresTotal / 60).ceil();
  int _expiresTotal = 600;

  static String normalize(String raw) => raw.trim().toLowerCase();

  final _edits = 0.obs;

  /// Seconds the send button stays blocked: a code for this same address is
  /// cooling down (the backend enforces it too). 0 = free to send.
  int get blockedSeconds {
    _edits.value; // rebuild observers when the address changes
    return resendIn.value > 0 && normalize(emailText.text) == _cooldownEmail
        ? resendIn.value
        : 0;
  }

  void onEmailChanged(String _) {
    _edits.value++;
    if (issue.value != null) issue.value = null;
  }

  Future<void> sendCode() async {
    if (sending.value || _login.isBusy) return;
    final email = normalize(emailText.text);
    if (!_emailPattern.hasMatch(email)) {
      issue.value = const EmailIssue(EmailIssueKind.invalidEmail);
      return;
    }
    if (blockedSeconds > 0) return;
    sending.value = true;
    issue.value = null;
    try {
      final challenge = await _repository.startEmailSignIn(
        email: email,
        locale: _localeCode() == 'en' ? 'en' : 'es',
      );
      sentTo.value = email;
      _expiresTotal = challenge.expiresInSeconds;
      expiresIn.value = challenge.expiresInSeconds;
      _startCooldown(email, challenge.resendAfterSeconds);
      codeText.clear();
      stage.value = EmailStage.code;
      codeFocus.requestFocus();
    } catch (e) {
      issue.value = _issueFor(e, startingCode: true);
      final wait = issue.value?.seconds;
      if (wait != null && wait > 0) _startCooldown(email, wait);
    } finally {
      sending.value = false;
    }
  }

  /// Called on every edit of the code field; submits as soon as it is full.
  void onCodeChanged(String value) {
    if (issue.value != null) issue.value = null;
    if (value.length == codeLength) verifyCode();
  }

  Future<void> verifyCode() async {
    final code = codeText.text;
    if (code.length != codeLength || _login.isBusy) return;
    issue.value = null;
    final error = await _login.signInWithEmailCode(sentTo.value, code);
    if (error == null) return;
    issue.value = _issueFor(error, startingCode: false);
    codeText.clear();
    codeFocus.requestFocus();
    final wait = issue.value?.seconds;
    if (wait != null && wait > 0) _startCooldown(sentTo.value, wait);
  }

  /// Back to the address field (typo, other mailbox).
  void changeEmail() {
    issue.value = null;
    codeText.clear();
    stage.value = EmailStage.address;
  }

  void _startCooldown(String email, int seconds) {
    _cooldownEmail = email;
    resendIn.value = seconds;
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (resendIn.value > 0) resendIn.value--;
    if (expiresIn.value > 0) {
      expiresIn.value--;
      if (expiresIn.value == 0 && stage.value == EmailStage.code) {
        issue.value ??= const EmailIssue(EmailIssueKind.codeExpired);
      }
    }
    if (resendIn.value == 0 && expiresIn.value == 0) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  EmailIssue _issueFor(Object error, {required bool startingCode}) {
    if (error is AppException) {
      switch (error.code) {
        case 'INVALID_CODE':
          return EmailIssue(
            EmailIssueKind.invalidCode,
            attemptsLeft: error.intField('attemptsLeft'),
          );
        case 'CODE_EXPIRED':
          expiresIn.value = 0;
          return const EmailIssue(EmailIssueKind.codeExpired);
        case 'TOO_MANY_ATTEMPTS':
          expiresIn.value = 0;
          return const EmailIssue(EmailIssueKind.tooManyAttempts);
      }
      if (error.kind == AppErrorKind.rateLimited) {
        return EmailIssue(
          EmailIssueKind.rateLimited,
          seconds: error.intField('retryAfterSeconds'),
          message: userMessageFor(error),
        );
      }
      if (startingCode && error.kind == AppErrorKind.validation) {
        return const EmailIssue(EmailIssueKind.invalidEmail);
      }
    }
    return EmailIssue(EmailIssueKind.other, message: userMessageFor(error));
  }

  /// Stops the countdown (also on close).
  void cancelTimers() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void onClose() {
    cancelTimers();
    emailText.dispose();
    codeText.dispose();
    codeFocus.dispose();
    super.onClose();
  }
}
