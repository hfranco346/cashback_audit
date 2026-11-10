import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/routing/app_navigator.dart';
import '../../verifications/presentation/format_reward.dart';
import '../../verifications/presentation/period_label.dart';
import '../../verifications/domain/verification_entities.dart';
import 'claim_controller.dart';
import 'widgets/claim_view.dart';

/// Container of the claim screen. Texts of the email follow the selected
/// email language; the rest of the screen follows the app language.
class ClaimPage extends GetView<ClaimController> {
  const ClaimPage({super.key});

  /// Header line (card, period and difference) in the app language.
  static String summaryFor(Verification v, String cardLabel) {
    final diff = v.difference;
    final amount = diff == null
        ? null
        : formatReward(diff, v.unit, currency: v.resolvedRewardCurrency);
    return [
      cardLabel,
      statementPeriodLabel(v.statement, v.createdAt),
      ?amount,
    ].where((e) => e.isNotEmpty).join(' · ');
  }

  Future<void> _run(
    BuildContext context,
    Future<ClaimResult> Function() action,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final r = await action();
    final text = switch (r.outcome) {
      ClaimOutcome.copied => l10n.claimCopied,
      ClaimOutcome.noMailApp => l10n.claimNoMailApp,
      ClaimOutcome.invalidEmail => l10n.claimInvalidEmail,
      ClaimOutcome.opened => r.saveFailed ? l10n.claimSaveFailed : null,
    };
    final message = r.saveFailed && r.outcome != ClaimOutcome.opened
        ? '$text ${l10n.claimSaveFailed}'
        : text;
    if (message == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      body: SafeArea(
        child: Obx(
          () => ClaimView(
            summary: summaryFor(c.verification, c.cardLabel),
            language: c.language.value,
            onLanguage: c.setLanguage,
            tone: c.tone.value,
            onTone: c.setTone,
            toField: c.toField,
            email: c.email,
            busy: c.saving.value,
            onBack: Get.find<AppNavigator>().pop,
            onCopy: () => _run(context, c.copy),
            onOpenMail: () => _run(context, c.openMail),
          ),
        ),
      ),
    );
  }
}
