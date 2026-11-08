import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../shared/widgets/molecules/empty_state.dart';
import '../../../../shared/widgets/molecules/inline_message.dart';
import '../../../cards/domain/card_entities.dart';
import '../../domain/pdf_picker.dart';
import '../upload_controller.dart' show UploadPhase;
import 'analyzing_progress.dart';

/// Pure presentational "upload statement" screen.
class UploadView extends StatelessWidget {
  const UploadView({
    super.key,
    required this.cards,
    required this.selectedCardId,
    required this.onSelectCard,
    required this.file,
    required this.onPick,
    required this.phase,
    required this.progress,
    required this.canSubmit,
    required this.onSubmit,
    required this.onAddCard,
    this.errorMessage,
  });

  final List<CreditCard> cards;
  final String? selectedCardId;
  final ValueChanged<String> onSelectCard;
  final PickedPdf? file;
  final VoidCallback onPick;
  final UploadPhase phase;
  final double progress;
  final bool canSubmit;
  final VoidCallback onSubmit;
  final VoidCallback onAddCard;
  final String? errorMessage;

  bool get _busy => phase != UploadPhase.idle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text(S.uploadTitle)),
        body: EmptyState(
          icon: Icons.credit_card_off_rounded,
          title: S.homeNoCardsTitle,
          message: S.noCardsForUpload,
          actionLabel: S.addCard,
          onAction: onAddCard,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text(S.uploadTitle)),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Text(S.uploadStep1, style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in cards)
                    ChoiceChip(
                      key: Key('card-chip-${c.id}'),
                      label: Text('${c.alias} · ${c.last4}'),
                      selected: selectedCardId == c.id,
                      onSelected: _busy ? null : (_) => onSelectCard(c.id),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text(S.uploadStep2, style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              _FileBox(file: file, onPick: _busy ? null : onPick),
              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                InlineMessage(message: errorMessage!),
              ],
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('verify-button'),
                onPressed: canSubmit ? onSubmit : null,
                child: const Text(S.verify),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      S.uploadPrivacy,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: theme.colorScheme.surface.withValues(alpha: 0.94),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          phase == UploadPhase.uploading
                              ? S.uploading
                              : S.analyzing,
                          key: const Key('upload-phase'),
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        LinearProgressIndicator(
                          key: const Key('upload-progress'),
                          value: phase == UploadPhase.uploading
                              ? progress
                              : null,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        const SizedBox(height: 20),
                        if (phase == UploadPhase.analyzing)
                          const AnalyzingProgress()
                        else
                          Text(
                            S.analyzingHint,
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FileBox extends StatelessWidget {
  const _FileBox({required this.file, required this.onPick});

  final PickedPdf? file;
  final VoidCallback? onPick;

  String _size(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).ceil()} KB';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: const Key('file-box'),
      onTap: onPick,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: file == null
                ? theme.colorScheme.outline
                : theme.colorScheme.primary,
            width: file == null ? 1 : 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              file == null
                  ? Icons.upload_file_rounded
                  : Icons.picture_as_pdf_rounded,
              size: 34,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: file == null
                  ? Text(S.pickPdf, style: theme.textTheme.titleSmall)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          '${_size(file!.sizeBytes)} · ${S.changePdf}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
