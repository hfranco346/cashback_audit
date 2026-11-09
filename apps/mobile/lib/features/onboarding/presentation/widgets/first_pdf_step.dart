import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../verifications/presentation/failure_text.dart';
import '../../../verifications/presentation/widgets/processing_checklist.dart';
import '../onboarding_controller.dart';
import 'onboarding_frame.dart';

/// Step 5: the first PDF with the free check. The upload returns at once; the
/// analysis continues in the backend, so the user can leave at any time.
class FirstPdfStep extends StatelessWidget {
  const FirstPdfStep({super.key, required this.controller, this.userName});

  final OnboardingController controller;
  final String? userName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final c = controller;
    return OnboardingFrame(
      step: 5,
      stepName: l10n.onbStepFreeCheck,
      onBack: c.back,
      footer: Obx(() {
        switch (c.pdfPhase.value) {
          case FirstPdfPhase.pick:
          case FirstPdfPhase.uploading:
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton(
                  key: const Key('onb-analyze'),
                  label: l10n.onbPdfStart,
                  loading: c.pdfPhase.value == FirstPdfPhase.uploading,
                  onPressed: c.canAnalyze ? c.startAnalysis : null,
                ),
                TextButton(
                  key: const Key('onb-later'),
                  onPressed: c.leaveToHome,
                  child: Text(l10n.onbPdfLater),
                ),
              ],
            );
          case FirstPdfPhase.processing:
            return AppButton.ghost(
              key: const Key('onb-leave'),
              label: l10n.processingLeave,
              onPressed: c.leaveToHome,
            );
          case FirstPdfPhase.failed:
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton(
                  key: const Key('onb-retry-pdf'),
                  label: l10n.onbPdfChange,
                  onPressed: c.retryPdf,
                ),
                TextButton(
                  onPressed: c.leaveToHome,
                  child: Text(l10n.onbGoHome),
                ),
              ],
            );
        }
      }),
      child: Obx(() {
        final phase = c.pdfPhase.value;
        final file = c.file.value;
        final d = c.draft.value;
        final cardLabel = '${c.cardName} •••• ${d.last4}';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: StatusPill(
                    kind: StatusKind.ok,
                    label: l10n.onbFreeCheckPill,
                  ),
                ),
                if (userName != null)
                  Flexible(
                    child: Text(
                      l10n.onbHello(userName!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            OnboardingTitle(
              title: phase == FirstPdfPhase.pick
                  ? l10n.onbPdfTitle
                  : l10n.onbPdfReadingTitle,
              subtitle: phase == FirstPdfPhase.pick ? l10n.onbPdfSub : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (file != null)
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
                          color: context.appColors.error.bg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'PDF',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: context.appColors.error.fg,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              l10n.onbPdfForCard(cardLabel),
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
            if (phase == FirstPdfPhase.pick) ...[
              if (file != null) const SizedBox(height: AppSpacing.md),
              AppButton.ghost(
                key: const Key('onb-pick-pdf'),
                label: file == null ? l10n.onbPdfPick : l10n.onbPdfChange,
                icon: Icons.upload_file_rounded,
                onPressed: c.pickPdf,
              ),
            ],
            if (phase == FirstPdfPhase.processing) ...[
              const SizedBox(height: AppSpacing.lg),
              ProcessingChecklist(
                cardLine: '${d.bank} · ${l10n.onbCardLast4} ${d.last4}',
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.processingCanLeave,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: muted,
                  height: 1.45,
                ),
              ),
            ],
            if (phase == FirstPdfPhase.failed) ...[
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusPill(
                    kind: StatusKind.error,
                    label: l10n.pendingFailedTitle,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                failureMessage(l10n, c.failure.value),
                key: const Key('onb-failure'),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (c.pdfError.value != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                switch (c.pdfError.value) {
                  'type' => l10n.fileNotPdf,
                  'size' => l10n.fileTooLarge,
                  final other => other!,
                },
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        );
      }),
    );
  }
}
