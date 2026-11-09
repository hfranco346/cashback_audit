import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui.dart';
import 'failure_text.dart';
import 'verification_progress_controller.dart';
import 'widgets/processing_checklist.dart';

/// "Reading your statement": shown right after an upload, and when the user
/// opens a pending verification from Home. Leaving is always allowed.
class VerificationProgressPage extends GetView<VerificationProgressController> {
  const VerificationProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.back,
          onPressed: controller.leave,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          final v = controller.verification.value;
          if (v != null && v.isFailed) {
            return _Failed(
              message: failureMessage(l10n, v.failureCode),
              onDone: controller.dismissFailure,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              0,
              AppSpacing.screen,
              AppSpacing.xxl,
            ),
            children: [
              Text(l10n.processingTitle, style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xl),
              ProcessingChecklist(cardLine: l10n.processingCardLine),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.processingCanLeave,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (controller.errorMessage.value != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  controller.errorMessage.value!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton.ghost(
                key: const Key('processing-leave'),
                label: l10n.processingLeave,
                onPressed: controller.leave,
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onDone});

  final String message;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(
              kind: StatusKind.error,
              label: l10n.pendingFailedTitle,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(message, style: theme.textTheme.titleMedium),
          const Spacer(),
          AppButton(label: l10n.processingDismiss, onPressed: onDone),
        ],
      ),
    );
  }
}
