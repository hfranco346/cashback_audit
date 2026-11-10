import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../cards/domain/card_entities.dart';
import '../../cards/domain/card_repository.dart';
import '../../cards/presentation/cards_controller.dart';
import '../../verifications/domain/verification_entities.dart';
import '../domain/claim_email.dart';
import '../domain/mail_launcher.dart';

/// What happened after tapping Copy or Open in Mail.
enum ClaimOutcome { copied, opened, noMailApp, invalidEmail }

class ClaimResult {
  const ClaimResult(this.outcome, {this.saveFailed = false});

  final ClaimOutcome outcome;

  /// The edited "To" could not be saved on the card (the action still ran).
  final bool saveFailed;
}

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Builds the claim email from a real verification and hands it to the
/// clipboard or the mail app. Keeps the card's `claimEmail` in sync.
class ClaimController extends GetxController {
  ClaimController({
    required this.verification,
    required this._launcher,
    required ClaimLanguage initialLanguage,
    this.card,
    this.userName,
    this.repository,
    this.cards,
  }) : language = initialLanguage.obs,
       _data = ClaimData.fromVerification(
         verification,
         card: card,
         userName: userName,
       );

  final Verification verification;
  final String? userName;
  final ClaimData _data;
  final MailLauncher _launcher;
  final ClaimEmailRepository? repository;
  final CardsController? cards;

  /// The card the verification belongs to; null when it was deleted.
  CreditCard? card;

  /// `BAC Cash •••• 4821`, or the bank and last 4 from the statement.
  String get cardLabel {
    final c = card;
    if (c != null) return '${c.alias} •••• ${c.last4}';
    return [
      ?_data.bank,
      if (_data.last4.isNotEmpty) '•••• ${_data.last4}',
    ].join(' ');
  }

  final Rx<ClaimLanguage> language;
  final tone = ClaimTone.formal.obs;
  final saving = false.obs;

  late final toField = TextEditingController(text: card?.claimEmail ?? '');

  ClaimData get data => _data;

  ClaimEmail get email => ClaimEmailBuilder.build(
    _data,
    language: language.value,
    tone: tone.value,
  );

  void setLanguage(ClaimLanguage l) => language.value = l;
  void setTone(ClaimTone t) => tone.value = t;

  String get _to => toField.text.trim();

  /// Valid when empty (the field is optional) or a plausible address.
  bool get toIsValid => _to.isEmpty || _emailPattern.hasMatch(_to);

  Future<ClaimResult> copy() async {
    if (!toIsValid) return const ClaimResult(ClaimOutcome.invalidEmail);
    final saveFailed = !await _saveRecipient();
    final e = email;
    await Clipboard.setData(ClipboardData(text: '${e.subject}\n\n${e.body}'));
    return ClaimResult(ClaimOutcome.copied, saveFailed: saveFailed);
  }

  Future<ClaimResult> openMail() async {
    if (!toIsValid) return const ClaimResult(ClaimOutcome.invalidEmail);
    final saveFailed = !await _saveRecipient();
    final e = email;
    final opened = await _launcher.open(
      buildMailto(to: _to, subject: e.subject, body: e.body),
    );
    return ClaimResult(
      opened ? ClaimOutcome.opened : ClaimOutcome.noMailApp,
      saveFailed: saveFailed,
    );
  }

  /// PATCHes the card when the recipient changed. Returns false on failure.
  Future<bool> _saveRecipient() async {
    final current = card;
    final repo = repository;
    final next = _to.isEmpty ? null : _to;
    if (current == null || repo == null || next == current.claimEmail) {
      return true;
    }
    saving.value = true;
    try {
      final updated = await repo.setClaimEmail(current.id, next);
      card = updated;
      cards?.replace(updated);
      return true;
    } on AppException {
      return false;
    } finally {
      saving.value = false;
    }
  }

  @override
  void onClose() {
    toField.dispose();
    super.onClose();
  }
}
