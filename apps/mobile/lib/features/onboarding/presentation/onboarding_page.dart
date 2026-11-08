import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/strings.dart';
import '../../../shared/widgets/atoms/app_logo_mark.dart';
import '../../../shared/widgets/atoms/dots_indicator.dart';
import 'onboarding_controller.dart';
import 'widgets/onboarding_slide_view.dart';

class OnboardingPage extends GetView<OnboardingController> {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    const slides = OnboardingController.slides;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  const AppLogoMark(size: 40),
                  const Spacer(),
                  Obx(
                    () => controller.isLast
                        ? const SizedBox(height: 48)
                        : TextButton(
                            onPressed: controller.finish,
                            child: const Text(S.skip),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: controller.pageController,
                onPageChanged: controller.onPageChanged,
                itemCount: slides.length,
                itemBuilder: (_, i) => OnboardingSlideView(
                  key: ValueKey('slide-$i'),
                  icon: slides[i].icon,
                  title: slides[i].title,
                  body: slides[i].body,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  Obx(
                    () => DotsIndicator(
                      count: slides.length,
                      index: controller.index.value,
                    ),
                  ),
                  const Spacer(),
                  Obx(
                    () => FilledButton(
                      onPressed: controller.next,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(140, 52),
                      ),
                      child: Text(
                        controller.isLast ? S.start : S.continueLabel,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
