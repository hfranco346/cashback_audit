import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import 'processing_checklist.dart';

/// "Reading your statement" body shared by the upload flow and the progress
/// page: the PDF being read, the analysis track and steps, and the promise
/// that the user can leave and find the result on Home.
class ProcessingPanel extends StatelessWidget {
  const ProcessingPanel({
    super.key,
    this.fileName,
    this.cardLabel,
    this.progress,
    this.title,
    this.etaLabel,
    this.errorMessage,
  });

  final String? fileName;

  /// `BAC Cash •••• 4821`.
  final String? cardLabel;
  final double? progress;
  final String? title;
  final String? etaLabel;

  /// Non-fatal connectivity hint while polling continues.
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.appColors;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (fileName != null || cardLabel != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.error.bg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.processingFileBadge,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.error.fg,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (fileName != null)
                          Text(
                            fileName!,
                            key: const Key('processing-file'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        if (cardLabel != null)
                          Text(
                            cardLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        ProcessingChecklist(
          progress: progress,
          title: title,
          etaLabel: etaLabel,
          cardLine: l10n.processingCardLine,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.notifications_none_rounded, size: 16, color: muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.processingCanLeave,
                key: const Key('processing-can-leave'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: muted,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          InlineNotice(message: errorMessage!, kind: StatusKind.warning),
        ],
      ],
    );
  }
}
