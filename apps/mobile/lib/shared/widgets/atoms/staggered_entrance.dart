import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

/// Fade-in-up entrance whose delay grows with [index], for list items.
/// The delay is capped so long lists do not feel slow.
class StaggeredEntrance extends StatelessWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.step = const Duration(milliseconds: 60),
    this.maxDelay = const Duration(milliseconds: 420),
  });

  final int index;
  final Widget child;
  final Duration step;
  final Duration maxDelay;

  @override
  Widget build(BuildContext context) {
    final delay = step * index;
    return FadeInUp(
      from: 18,
      duration: const Duration(milliseconds: 380),
      delay: delay > maxDelay ? maxDelay : delay,
      child: child,
    );
  }
}
