import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../verifications/domain/verification_entities.dart';
import '../../../verifications/presentation/failure_text.dart';

/// One verification that needs the user, as a tappable banner:
/// processing (spinner), ready to confirm, new result, or failed (reason by
/// failure code; the credit was refunded).
class PendingBanner extends StatelessWidget {
  const PendingBanner({
    super.key,
    required this.item,
    required this.cardLabel,
    required this.onTap,
  });

  final VerificationSummary item;
  final String cardLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.appColors;
    final (
      StatusTone tone,
      String title,
      String body,
      Widget leading,
      String? action,
    ) = switch (item.status) {
      VerificationStatus.processing => (
        colors.neutral,
        l10n.pendingProcessingTitle,
        l10n.pendingProcessingBody(cardLabel),
        const SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
        null,
      ),
      VerificationStatus.awaitingRates => (
        colors.warning,
        l10n.pendingAwaitingTitle,
        '$cardLabel · ${l10n.pendingAwaitingBody}',
        Icon(Icons.schedule_rounded, size: 22, color: colors.warning.fg),
        l10n.pendingFollow,
      ),
      VerificationStatus.completed => (
        colors.success,
        l10n.pendingCompletedTitle,
        l10n.pendingCompletedBody(cardLabel),
        Icon(
          Icons.check_circle_outline_rounded,
          size: 22,
          color: colors.success.fg,
        ),
        null,
      ),
      VerificationStatus.failed => (
        colors.error,
        l10n.pendingFailedTitle,
        failureMessage(l10n, item.failureCode),
        Icon(Icons.error_outline_rounded, size: 22, color: colors.error.fg),
        null,
      ),
    };
    return Semantics(
      button: true,
      container: true,
      child: Material(
        color: tone.bg,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: Key('pending-${item.id}'),
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                SizedBox(width: 24, child: Center(child: leading)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: tone.fg,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tone.fg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    action,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: tone.fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ] else
                  Icon(Icons.chevron_right_rounded, color: tone.fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
