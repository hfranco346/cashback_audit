import 'package:flutter/material.dart';

/// The brand mark. Shared Hero tag lets it fly between splash, onboarding
/// and login.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.size = 56, this.heroTag = 'app-logo'});

  final double size;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        Icons.fact_check_rounded,
        color: scheme.onPrimary,
        size: size * 0.55,
      ),
    );
    return heroTag == null ? mark : Hero(tag: heroTag!, child: mark);
  }
}
