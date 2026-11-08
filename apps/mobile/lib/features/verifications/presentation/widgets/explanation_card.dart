import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';

/// The short Spanish narrative of the verdict, written by a cheap model from
/// numbers the server already computed.
class ExplanationCard extends StatelessWidget {
  const ExplanationCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('explanation-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(S.explanationTitle, style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(text, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
