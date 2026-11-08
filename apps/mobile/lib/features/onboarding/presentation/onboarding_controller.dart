import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/routing/app_navigator.dart';
import '../../../core/routing/app_routes.dart';
import '../domain/onboarding_repository.dart';

class OnboardingSlide {
  const OnboardingSlide({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class OnboardingController extends GetxController {
  OnboardingController({required this._repository, required this._navigator});

  final OnboardingRepository _repository;
  final AppNavigator _navigator;

  static const slides = <OnboardingSlide>[
    OnboardingSlide(
      icon: Icons.fact_check_rounded,
      title: S.onb1Title,
      body: S.onb1Body,
    ),
    OnboardingSlide(
      icon: Icons.credit_card_rounded,
      title: S.onb2Title,
      body: S.onb2Body,
    ),
    OnboardingSlide(
      icon: Icons.upload_file_rounded,
      title: S.onb3Title,
      body: S.onb3Body,
    ),
    OnboardingSlide(
      icon: Icons.lock_outline_rounded,
      title: S.onb4Title,
      body: S.onb4Body,
    ),
  ];

  final pageController = PageController();
  final index = 0.obs;

  bool get isLast => index.value == slides.length - 1;

  void onPageChanged(int i) => index.value = i;

  Future<void> next() async {
    if (isLast) return finish();
    await pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> finish() async {
    await _repository.markOnboardingSeen();
    _navigator.offAll(Routes.login);
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}
