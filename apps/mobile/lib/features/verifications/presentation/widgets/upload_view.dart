import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../cards/domain/card_entities.dart';
import '../../../credits/domain/credit_entities.dart';
import '../../domain/pdf_picker.dart';
import '../upload_controller.dart' show UploadPhase;
import 'processing_panel.dart';

/// Pure presentational "check a statement" screen: pick the card, pick the
/// PDF, analyze. While the file travels it shows the reading state.
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
    required this.onClose,
    this.balance,
    this.onSeePlans,
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
  final VoidCallback onClose;

  /// Credit balance (`null` while unknown) for the pre-upload notice.
  final CreditBalance? balance;
  final VoidCallback? onSeePlans;
  final String? errorMessage;

  bool get _busy => phase != UploadPhase.idle;

  CreditCard? get _selected {
    for (final c in cards) {
      if (c.id == selectedCardId) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final close = IconButton(
      key: const Key('verify-close'),
      tooltip: l10n.verifyClose,
      onPressed: _busy ? null : onClose,
      icon: const Icon(Icons.close_rounded),
    );
    if (cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(leading: close),
        body: _NoCards(onAddCard: onAddCard),
      );
    }
    if (_busy) {
      final card = _selected;
      return Scaffold(
        appBar: AppBar(leading: close),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              0,
              AppSpacing.screen,
              AppSpacing.xxl,
            ),
            children: [
              Text(l10n.processingTitle, style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.lg),
              ProcessingPanel(
                key: const Key('upload-processing'),
                fileName: file?.name,
                cardLabel: card == null
                    ? null
                    : '${card.alias} •••• ${card.last4}',
                progress: phase == UploadPhase.uploading ? progress : null,
                title: phase == UploadPhase.uploading ? l10n.uploading : null,
                etaLabel: phase == UploadPhase.uploading
                    ? l10n.processingUploadingEta
                    : null,
              ),
            ],
          ),
        ),
      );
    }
    final ready = canSubmit;
    return Scaffold(
      appBar: AppBar(leading: close),
      body: SafeArea(
        child: Column(
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
                  Text(l10n.uploadTitle, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(title: l10n.verifyStepCard, caption: true),
                  const SizedBox(height: 10),
                  Semantics(
                    container: true,
                    child: Column(
                      children: [
                        for (var i = 0; i < cards.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _CardOption(
                              key: Key('card-chip-${cards[i].id}'),
                              card: cards[i],
                              alt: i.isOdd,
                              selected: selectedCardId == cards[i].id,
                              onTap: () => onSelectCard(cards[i].id),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SectionHeader(title: l10n.verifyStepFile, caption: true),
                  const SizedBox(height: 10),
                  _FileBox(file: file, onPick: onPick),
                  if (errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    InlineNotice(
                      key: const Key('upload-error'),
                      message: errorMessage!,
                    ),
                  ],
                  if (balance != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _CreditNote(balance: balance!, onSeePlans: onSeePlans),
                  ],
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
                child: AppButton(
                  key: const Key('verify-button'),
                  label: ready
                      ? l10n.verifyCta
                      : selectedCardId == null
                      ? l10n.verifyCtaPickCard
                      : l10n.verifyCtaPickFile,
                  onPressed: ready ? onSubmit : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoCards extends StatelessWidget {
  const _NoCards({required this.onAddCard});

  final VoidCallback onAddCard;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.uploadTitle, style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.noCardsForUpload,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          AppButton(
            key: const Key('verify-add-card'),
            label: l10n.addCard,
            onPressed: onAddCard,
          ),
        ],
      ),
    );
  }
}

/// One radio option of the card list (`.opt`): mini card, name + digits,
/// "Cashback in HNL · 2 rules" and the radio.
class _CardOption extends StatelessWidget {
  const _CardOption({
    super.key,
    required this.card,
    required this.alt,
    required this.selected,
    required this.onTap,
  });

  final CreditCard card;
  final bool alt;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;
    final rules = l10n.ruleCount(card.rules.length);
    final subtitle = card.isPoints
        ? l10n.verifyCardPoints(rules)
        : l10n.verifyCardCashback(card.rewardCurrency ?? card.currency, rules);
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: Material(
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 68),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 34,
                    decoration: BoxDecoration(
                      color: alt ? const Color(0xFF3B2F1C) : colors.creditCard,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: colors.brass.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${card.alias} •••• ${card.last4}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? scheme.primary
                            : scheme.outlineVariant,
                        width: selected ? 7 : 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FileBox extends StatelessWidget {
  const _FileBox({required this.file, required this.onPick});

  final PickedPdf? file;
  final VoidCallback onPick;

  String _size(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).ceil()} KB';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final picked = file;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(
          color: picked == null ? scheme.outlineVariant : scheme.primary,
          width: picked == null ? 1.5 : 2,
        ),
      ),
      child: InkWell(
        key: const Key('file-box'),
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: onPick,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  picked == null
                      ? Icons.upload_file_rounded
                      : Icons.picture_as_pdf_rounded,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                picked?.name ?? l10n.pickPdf,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10 - 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(
                  picked == null
                      ? l10n.verifyPickHint
                      : '${_size(picked.sizeBytes)} · ${l10n.changePdf}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the analysis will cost: availability pill + the "only used if the
/// read succeeds" promise, or the no-credits notice with the plans action.
class _CreditNote extends StatelessWidget {
  const _CreditNote({required this.balance, required this.onSeePlans});

  final CreditBalance balance;
  final VoidCallback? onSeePlans;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (!balance.hasCredits) {
      return InlineNotice(
        key: const Key('upload-no-credits'),
        message: l10n.uploadNoCredits,
        kind: StatusKind.warning,
        actionLabel: l10n.seePlans,
        onAction: onSeePlans,
      );
    }
    return Card(
      key: const Key('upload-credit-note'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            StatusPill(
              kind: StatusKind.ok,
              label: l10n.verifyAvailablePill(balance.total),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.verifyCreditNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
