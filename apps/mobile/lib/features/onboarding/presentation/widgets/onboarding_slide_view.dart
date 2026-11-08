import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

/// Pure presentational onboarding page; its entrance animations run each
/// time the page is built by the PageView.
class OnboardingSlideView extends StatelessWidget {
  const OnboardingSlideView({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BounceInDown(
            duration: const Duration(milliseconds: 700),
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(34),
              ),
              child: Icon(icon, size: 52, color: scheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(height: 40),
          FadeInUp(
            delay: const Duration(milliseconds: 150),
            child: Text(title, style: theme.textTheme.headlineMedium),
          ),
          const SizedBox(height: 14),
          FadeInUp(
            delay: const Duration(milliseconds: 300),
            child: Text(
              body,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
