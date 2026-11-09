import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../auth/presentation/login_controller.dart';
import '../../auth/presentation/session_controller.dart';
import '../../settings/presentation/locale_controller.dart';
import '../domain/onboarding_draft.dart';
import 'onboarding_controller.dart';
import 'widgets/account_step.dart';
import 'widgets/demo_step.dart';
import 'widgets/first_pdf_step.dart';
import 'widgets/setup_steps.dart';
import 'widgets/verdict_step.dart';

/// Container of the guided setup: one screen per [OnboardingStep] with a soft
/// cross-fade between them.
class OnboardingPage extends GetView<OnboardingController> {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      body: Obx(() {
        final step = c.step.value;
        final Widget view = switch (step) {
          OnboardingStep.demo => DemoStep(
            locale: Get.find<LocaleController>(),
            onStart: c.start,
            onHaveAccount: c.haveAccount,
          ),
          OnboardingStep.bank => BankStep(controller: c),
          OnboardingStep.card => CardStep(controller: c),
          OnboardingStep.categories => CategoriesStep(controller: c),
          OnboardingStep.account => AccountStep(
            controller: c,
            login: Get.find<LoginController>(),
          ),
          OnboardingStep.pdf => FirstPdfStep(
            controller: c,
            userName: Get.find<SessionController>().user.value?.firstName,
          ),
          OnboardingStep.verdict =>
            c.verification.value == null
                ? const SizedBox.shrink()
                : VerdictStep(
                    verification: c.verification.value!,
                    cardName: c.cardName,
                    categoryCount: c.draft.value.categories.length,
                    onDetail: c.openDetail,
                    onHome: c.leaveToHome,
                  ),
        };
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(key: ValueKey(step), child: view),
        );
      }),
    );
  }
}
