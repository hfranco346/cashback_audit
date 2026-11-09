import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_theme.dart';
import 'splash_controller.dart';

/// Splash: credit-card green with the brass monogram, the app name in Bodoni
/// and the tagline in brass capitals.
class SplashPage extends GetView<SplashController> {
  const SplashPage({super.key});

  static const _brass = Color(0xFFCDAE6E);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: colors.creditCard,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ZoomIn(
              duration: const Duration(milliseconds: 700),
              child: Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: _brass.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  'C',
                  style: text.displaySmall?.copyWith(
                    color: colors.onCreditCard,
                    fontSize: 48,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            FadeInUp(
              delay: const Duration(milliseconds: 500),
              from: 14,
              child: Column(
                children: [
                  Text(
                    l10n.appName,
                    style: text.displaySmall?.copyWith(
                      color: colors.onCreditCard,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.splashTagline.toUpperCase(),
                    style: text.labelMedium?.copyWith(
                      color: _brass,
                      letterSpacing: 1.9,
                      fontWeight: FontWeight.w700,
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
