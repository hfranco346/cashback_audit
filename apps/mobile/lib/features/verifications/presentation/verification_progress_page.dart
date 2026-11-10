import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui.dart';
import '../domain/verification_entities.dart';
import 'failure_text.dart';
import 'verification_progress_controller.dart';
import 'widgets/delete_verification_dialog.dart';
import 'widgets/processing_panel.dart';

/// "Reading your statement": shown right after an upload, and when the user
/// opens a pending verification from Home. Leaving is always allowed; a
/// failed analysis explains why, says the credit came back and offers a
/// retry.
class VerificationProgressPage extends GetView<VerificationProgressController> {
  const VerificationProgressPage({super.key});

  Future<void> _delete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmDeleteVerification(
      context,
      creditLost: controller.deleteLosesCreditNote,
    );
    if (!ok) return;
    final error = await controller.deleteVerification();
    if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.verifyClose,
          onPressed: controller.leave,
          icon: const Icon(Icons.close_rounded),
        ),
        actions: [DeleteVerificationMenu(onDelete: () => _delete(context))],
      ),
      body: SafeArea(
        child: Obx(() {
          final v = controller.verification.value;
          if (v != null && v.isFailed) {
            return FailedAnalysis(
              code: v.failureCode,
              onRetry: controller.retryUpload,
              onDone: controller.dismissFailure,
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    0,
                    AppSpacing.screen,
                    AppSpacing.lg,
                  ),
                  children: [
                    Text(
                      l10n.processingTitle,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ProcessingPanel(
                      fileName: controller.fileName,
                      cardLabel: controller.cardLabel,
                      errorMessage: controller.errorMessage.value,
                    ),
                  ],
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    AppSpacing.md,
                    AppSpacing.screen,
                    AppSpacing.lg,
                  ),
                  child: AppButton.ghost(
                    key: const Key('processing-leave'),
                    label: l10n.processingBackground,
                    onPressed: controller.leave,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// Failed analysis: reason by [FailureCode], the refunded credit and the
/// way forward. Pure presentational.
class FailedAnalysis extends StatelessWidget {
  const FailedAnalysis({
    super.key,
    required this.code,
    required this.onRetry,
    required this.onDone,
  });

  final FailureCode? code;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final notAStatement = code == FailureCode.notAStatement;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          FadeInUp(
            from: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    StatusPill(
                      kind: StatusKind.error,
                      label: l10n.pendingFailedTitle,
                    ),
                    StatusPill(
                      key: const Key('failure-refunded'),
                      kind: StatusKind.ok,
                      icon: Icons.undo_rounded,
                      label: l10n.failureRefundedPill,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  failureTitle(l10n, code),
                  key: const Key('failure-title'),
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  failureMessage(l10n, code),
                  key: const Key('failure-message'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          AppButton(
            key: const Key('failure-retry'),
            label: notAStatement
                ? l10n.failureChooseAnother
                : l10n.failureRetry,
            onPressed: onRetry,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton.ghost(
            key: const Key('failure-home'),
            label: l10n.processingLeave,
            onPressed: onDone,
          ),
        ],
      ),
    );
  }
}
