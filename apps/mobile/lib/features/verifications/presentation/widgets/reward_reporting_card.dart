import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/active_locale.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../cards/domain/card_entities.dart';
import '../../domain/verification_entities.dart';
import '../format_reward.dart';
import 'reward_derivation.dart';

/// "Reward reported by your bank": the figure the statement prints, the
/// question of whether it is the month's reward or the accumulated balance
/// (remembered per card) and, for a balance, the previous balance with its
/// source plus the live derivation of what was earned.
class RewardReportingCard extends StatelessWidget {
  const RewardReportingCard({
    super.key,
    required this.proposal,
    required this.mode,
    required this.onMode,
    required this.remember,
    required this.onRemember,
    required this.previousBalance,
    required this.previousSource,
    required this.previousRequired,
    required this.onPreviousTouched,
    required this.unit,
    required this.currency,
    this.programName,
    this.previousError,
    this.earned,
    this.onUpload,
    this.uploading = false,
    this.uploadProgress = 0,
    this.uploadError,
    this.programChoices = const [],
    this.onChooseProgram,
    this.busy = false,
  });

  final RewardReportingProposal proposal;
  final RewardReporting mode;
  final ValueChanged<RewardReporting> onMode;
  final bool remember;
  final ValueChanged<bool> onRemember;

  final TextEditingController previousBalance;
  final PreviousBalanceSource? previousSource;

  /// Cumulative figure without a previous balance yet (red, required).
  final bool previousRequired;
  final String? previousError;
  final VoidCallback onPreviousTouched;

  final RewardUnit unit;
  final String currency;
  final String? programName;

  /// Live result of the derivation (or the amount the statement prints).
  final Decimal? earned;

  /// Null hides the "upload last month's PDF" action.
  final VoidCallback? onUpload;
  final bool uploading;
  final double uploadProgress;
  final String? uploadError;
  final List<PreviousStatementProgram> programChoices;
  final ValueChanged<PreviousStatementProgram>? onChooseProgram;
  final bool busy;

  static final _decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

  bool get _cumulative => mode == RewardReporting.cumulative;

  String? _reason(BuildContext context) {
    final l10n = context.l10n;
    return switch (proposal.reason) {
      ReportingReason.statementHasPreviousBalance =>
        l10n.reportingReasonStatementPrev,
      ReportingReason.cardSetting => l10n.reportingReasonCard,
      ReportingReason.labelSaysAccumulated =>
        proposal.reportedLabel == null
            ? l10n.reportingReasonLabelGeneric
            : l10n.reportingReasonLabel(proposal.reportedLabel!),
      ReportingReason.reportedFarAboveExpected => l10n.reportingReasonFar,
      ReportingReason.none => null,
    };
  }

  (StatusKind, IconData, String) _sourceBadge(BuildContext context) {
    final l10n = context.l10n;
    if (previousRequired || previousSource == null) {
      return (
        previousRequired ? StatusKind.error : StatusKind.neutral,
        previousRequired ? Icons.error_outline_rounded : Icons.edit_outlined,
        previousRequired ? l10n.badgeRequired : l10n.reportingPrevSourceUser,
      );
    }
    return switch (previousSource!) {
      PreviousBalanceSource.statement => (
        StatusKind.ok,
        Icons.description_outlined,
        l10n.reportingPrevSourceStatement,
      ),
      PreviousBalanceSource.previousVerification => (
        StatusKind.neutral,
        Icons.history_rounded,
        proposal.previousPeriodEnd == null
            ? l10n.reportingPrevSourceVerification
            : l10n.reportingPrevSourceVerificationMonth(
                toBeginningOfSentenceCase(
                  DateFormat.MMMM(ActiveLocale.intlName)
                      .format(proposal.previousPeriodEnd!),
                ),
              ),
      ),
      PreviousBalanceSource.user => (
        StatusKind.neutral,
        Icons.edit_outlined,
        l10n.reportingPrevSourceUser,
      ),
      PreviousBalanceSource.previousStatement => (
        StatusKind.ok,
        Icons.picture_as_pdf_outlined,
        l10n.reportingPrevSourcePdf,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.appColors;
    final muted = theme.colorScheme.onSurfaceVariant;
    final current = proposal.currentBalance;
    final reason = _reason(context);
    final red = previousRequired || previousError != null;
    final (kind, icon, badge) = _sourceBadge(context);
    final negative = earned != null && earned! < Decimal.zero;
    String fmt(Decimal d) => formatReward(d, unit, currency: currency);
    return Card(
      key: const Key('reward-reporting-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.reportingTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            if (programName != null || current != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      programName ?? l10n.reportingFigure,
                      key: const Key('reporting-program'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (current != null) ...[
                    const SizedBox(width: 12),
                    AmountText.text(
                      fmt(current),
                      key: const Key('reporting-figure'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 8),
            StatusPill(
              kind: StatusKind.ok,
              label: l10n.badgeStatement,
              icon: Icons.description_outlined,
            ),
            if (proposal.reportedLabel != null) ...[
              const SizedBox(height: 10),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 2, color: colors.brass),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.evidenceQuote(proposal.reportedLabel!),
                        key: const Key('reporting-quote'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              l10n.reportingQuestion,
              style: theme.textTheme.titleSmall?.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 10),
            AppSegmented<RewardReporting>(
              key: const Key('reporting-mode'),
              options: [
                SegmentOption(
                  value: RewardReporting.monthly,
                  label: l10n.reportingModeMonthly,
                ),
                SegmentOption(
                  value: RewardReporting.cumulative,
                  label: l10n.reportingModeCumulative,
                ),
              ],
              selected: mode,
              onChanged: busy ? (_) {} : onMode,
            ),
            if (reason != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reason,
                      key: const Key('reporting-reason'),
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.reportingRemember,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        l10n.reportingRememberHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  key: const Key('reporting-remember'),
                  value: remember,
                  onChanged: busy ? null : onRemember,
                ),
              ],
            ),
            if (_cumulative) ...[
              const SizedBox(height: 12),
              Container(
                key: const Key('previous-balance-box'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.field),
                  border: Border.all(
                    color: red
                        ? theme.colorScheme.error
                        : theme.colorScheme.outlineVariant,
                    width: red ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppField(
                      label: l10n.reportingPreviousLabel,
                      help: l10n.reportingPreviousHelp,
                      child: TextField(
                        key: const Key('previous-balance-field'),
                        controller: previousBalance,
                        enabled: !busy,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [_decimal],
                        onTapOutside: (_) => onPreviousTouched(),
                        textAlign: TextAlign.end,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFeatures: appFigures,
                        ),
                        decoration: AppField.decoration(
                          hint: '0.00',
                          suffix: unit == RewardUnit.points ? 'pts' : currency,
                        ).copyWith(errorText: previousError),
                      ),
                    ),
                    const SizedBox(height: 10),
                    StatusPill(kind: kind, label: badge, icon: icon),
                    if (previousRequired) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.reportingPreviousRequired,
                        key: const Key('previous-required'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.error.fg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (onUpload != null) ...[
                      const SizedBox(height: 10),
                      _UploadPrevious(
                        onUpload: onUpload!,
                        uploading: uploading,
                        progress: uploadProgress,
                        highlight: previousRequired,
                      ),
                    ],
                    if (uploadError != null) ...[
                      const SizedBox(height: 8),
                      InlineNotice(
                        key: const Key('previous-upload-error'),
                        message: uploadError!,
                      ),
                    ],
                    if (programChoices.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        l10n.reportingPickProgram,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final p in programChoices)
                        ListTile(
                          key: Key('previous-program-${p.name}'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(p.name),
                          trailing: AmountText.text(
                            fmt(p.balance),
                            style: theme.textTheme.titleSmall,
                          ),
                          onTap: () => onChooseProgram?.call(p),
                        ),
                    ],
                  ],
                ),
              ),
              if (earned != null) ...[
                const SizedBox(height: 14),
                Text(
                  l10n.reportingBreakdownTitle.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: muted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                RewardDerivation(
                  unit: unit,
                  currency: currency,
                  current: proposal.currentBalance,
                  previous: _previousValue,
                  redeemed: proposal.redeemedInPeriod,
                  expired: proposal.expiredInPeriod,
                  earned: earned,
                ),
              ],
              if (negative) ...[
                const SizedBox(height: 10),
                InlineNotice(
                  key: const Key('reporting-negative'),
                  message: l10n.reportingNegativeWarning,
                  kind: StatusKind.warning,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Decimal? get _previousValue {
    final t = previousBalance.text.trim().replaceAll(',', '.');
    return t.isEmpty ? null : Decimal.tryParse(t);
  }
}

class _UploadPrevious extends StatelessWidget {
  const _UploadPrevious({
    required this.onUpload,
    required this.uploading,
    required this.progress,
    required this.highlight,
  });

  final VoidCallback onUpload;
  final bool uploading;
  final double progress;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final sent = progress >= 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (highlight)
          AppButton(
            key: const Key('upload-previous'),
            label: l10n.reportingUploadCta,
            icon: Icons.upload_file_rounded,
            loading: uploading,
            onPressed: uploading ? null : onUpload,
          )
        else
          AppButton.ghost(
            key: const Key('upload-previous'),
            label: l10n.reportingUploadCta,
            icon: Icons.upload_file_rounded,
            loading: uploading,
            onPressed: uploading ? null : onUpload,
          ),
        const SizedBox(height: 6),
        if (uploading) ...[
          LinearProgressIndicator(
            key: const Key('upload-previous-progress'),
            value: sent || progress <= 0 ? null : progress,
          ),
          const SizedBox(height: 6),
          Text(
            sent ? l10n.reportingReading : l10n.reportingUploading,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ] else
          Text(
            l10n.reportingUploadNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: muted,
              height: 1.4,
            ),
          ),
      ],
    );
  }
}
