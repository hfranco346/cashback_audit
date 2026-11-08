import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/verification_entities.dart';

/// Colors, icon and copy for each [Verdict].
class VerdictStyle {
  const VerdictStyle({
    required this.color,
    required this.container,
    required this.icon,
    required this.label,
  });

  final Color color;
  final Color container;
  final IconData icon;
  final String label;

  factory VerdictStyle.of(BuildContext context, Verdict verdict) {
    final status = context.statusColors;
    final verdicts = context.verdictColors;
    return switch (verdict) {
      Verdict.match => VerdictStyle(
        color: status.success,
        container: status.successContainer,
        icon: Icons.verified_rounded,
        label: S.verdictMatch,
      ),
      Verdict.underpaid => VerdictStyle(
        color: status.danger,
        container: status.dangerContainer,
        icon: Icons.trending_down_rounded,
        label: S.verdictUnderpaid,
      ),
      Verdict.overpaid => VerdictStyle(
        color: verdicts.overpaid,
        container: verdicts.overpaidContainer,
        icon: Icons.trending_up_rounded,
        label: S.verdictOverpaid,
      ),
    };
  }
}
