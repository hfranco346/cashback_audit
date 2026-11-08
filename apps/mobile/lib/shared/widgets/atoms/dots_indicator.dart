import 'package:flutter/material.dart';

class DotsIndicator extends StatelessWidget {
  const DotsIndicator({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index ? scheme.primary : scheme.outlineVariant,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
      ],
    );
  }
}
