import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/verification_entities.dart';
import '../period_label.dart';
import '../result_controller.dart'
    show ResultNotice, ResultTab, TransactionFilter;
import 'delete_verification_dialog.dart';
import 'result_categories_tab.dart';
import 'result_movements_tab.dart';
import 'result_summary_tab.dart';

/// Pure presentational verification result: header, three tabs and the
/// recalculation overlay.
class VerificationResultView extends StatelessWidget {
  const VerificationResultView({
    super.key,
    required this.verification,
    required this.cardLabel,
    required this.tab,
    required this.onTab,
    required this.filter,
    required this.onFilterChanged,
    required this.onBack,
    this.onChangeCategory,
    this.onRecalculate,
    this.onDelete,
    this.onClaim,
    this.stale = false,
    this.recalculating = false,
    this.onRetryRecalculation,
    this.notice,
    this.onDismissNotice,
  });

  final Verification verification;

  /// `BAC Cash •••• 4821`.
  final String cardLabel;
  final ResultTab tab;
  final ValueChanged<ResultTab> onTab;
  final TransactionFilter filter;
  final ValueChanged<TransactionFilter> onFilterChanged;
  final VoidCallback onBack;

  /// Opens the "Change category" sheet for a statement line.
  final ValueChanged<VerificationTransaction>? onChangeCategory;

  /// Reopens the rate confirmation ("Recalculate with other %").
  final VoidCallback? onRecalculate;

  /// Opens the delete confirmation (⋮ menu); hidden when null.
  final VoidCallback? onDelete;

  /// Opens the claim email (offered for underpaid results only).
  final VoidCallback? onClaim;

  /// A correction was saved but the recalculation failed.
  final bool stale;
  final bool recalculating;
  final VoidCallback? onRetryRecalculation;
  final ResultNotice? notice;
  final VoidCallback? onDismissNotice;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final v = verification;
    final period = statementPeriodLabel(v.statement, v.createdAt);
    final body = switch (tab) {
      ResultTab.summary => ResultSummaryTab(
        verification: v,
        onRecalculate: onRecalculate,
        onClaim: onClaim,
        onReviewProgram: () => onTab(ResultTab.categories),
      ),
      ResultTab.categories => ResultCategoriesTab(
        verification: v,
        onRecalculate: onRecalculate,
      ),
      ResultTab.movements => ResultMovementsTab(
        verification: v,
        filter: filter,
        onFilterChanged: onFilterChanged,
        onChangeCategory: onChangeCategory,
      ),
    };
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('result-back'),
                    tooltip: l10n.back,
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cardLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          l10n.resultPeriodLine(period, v.transactions.length),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontFeatures: appFigures,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onRecalculate != null)
                    IconButton(
                      key: const Key('result-recalculate'),
                      tooltip: l10n.recalcWithOtherRates,
                      onPressed: onRecalculate,
                      icon: const Icon(Icons.percent_rounded),
                    ),
                  if (onDelete != null)
                    DeleteVerificationMenu(onDelete: onDelete!),
                ],
              ),
            ),
            _Tabs(tab: tab, onTab: onTab),
            if (stale || notice != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.md,
                  AppSpacing.screen,
                  0,
                ),
                child: stale
                    ? InlineNotice(
                        key: const Key('stale-banner'),
                        message: l10n.recalcFailedAfterChange,
                        kind: StatusKind.warning,
                        actionLabel: l10n.recalcAction,
                        onAction: onRetryRecalculation,
                      )
                    : InlineNotice(
                        key: const Key('result-notice'),
                        message: notice!.message,
                        kind: notice!.isError
                            ? StatusKind.error
                            : StatusKind.ok,
                        actionLabel: l10n.dismiss,
                        onAction: onDismissNotice,
                      ),
              ),
            Expanded(child: body),
          ],
        ),
        if (recalculating)
          Positioned.fill(
            child: ColoredBox(
              key: const Key('recalculating-overlay'),
              color: theme.colorScheme.surface.withValues(alpha: 0.6),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.tab, required this.onTab});

  final ResultTab tab;
  final ValueChanged<ResultTab> onTab;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labels = {
      ResultTab.summary: l10n.resultTabSummary,
      ResultTab.categories: l10n.resultTabCategories,
      ResultTab.movements: l10n.resultTabMovements,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          for (final t in ResultTab.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: t == tab,
                child: InkWell(
                  key: Key('result-tab-${t.name}'),
                  onTap: () => onTab(t),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: t == tab ? scheme.primary : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(
                      labels[t]!,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: t == tab
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
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
