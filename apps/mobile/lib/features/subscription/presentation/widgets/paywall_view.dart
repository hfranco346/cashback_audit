import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/subscription_entities.dart';
import '../paywall_controller.dart' show PaywallBusy;

/// Pure presentational paywall. Two states: with free checks left (a green
/// notice and "use my free check") and without credits (an amber notice).
/// Prices come from the store packages; payment is always the app store's.
class PaywallView extends StatelessWidget {
  const PaywallView({
    super.key,
    required this.configured,
    required this.subscription,
    required this.packs,
    required this.selectedId,
    required this.onSelect,
    required this.busy,
    required this.pending,
    required this.onPurchase,
    required this.onRestore,
    required this.onCheckAgain,
    required this.onClose,
    this.freeCredits = 0,
    this.errorMessage,
  });

  final bool configured;

  /// The monthly subscription of the offering, if it has one.
  final PaywallPackage? subscription;

  /// Consumable credit packs, smallest first.
  final List<PaywallPackage> packs;

  /// Free verifications the user still has.
  final int freeCredits;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final PaywallBusy busy;
  final bool pending;
  final String? errorMessage;
  final VoidCallback onPurchase;
  final VoidCallback onRestore;
  final VoidCallback onCheckAgain;
  final VoidCallback onClose;

  bool get _busy => busy != PaywallBusy.none;

  PaywallPackage? get _selected {
    for (final p in [?subscription, ...packs]) {
      if (p.id == selectedId) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;
    final hasFree = freeCredits > 0;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 8, 0),
                child: IconButton(
                  key: const Key('paywall-close'),
                  tooltip: l10n.paywallClose,
                  iconSize: 24,
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClose,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                children: [
                  ZoomIn(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.creditCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colors.brass.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          'C',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: colors.onCreditCard,
                            fontSize: 30,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeInUp(
                    from: 14,
                    child: Semantics(
                      header: true,
                      child: Text(
                        hasFree ? l10n.paywallTitleFree : l10n.paywallTitleNone,
                        key: const Key('paywall-title'),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontSize: 30,
                          height: 1.12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeIn(
                    delay: const Duration(milliseconds: 120),
                    child: hasFree
                        ? InlineNotice(
                            key: const Key('paywall-free-banner'),
                            kind: StatusKind.ok,
                            message: l10n.paywallFreeBanner(freeCredits),
                          )
                        : InlineNotice(
                            key: const Key('paywall-none-banner'),
                            kind: StatusKind.warning,
                            message: l10n.paywallBannerNone,
                          ),
                  ),
                  const SizedBox(height: 14),
                  for (final (i, text) in [
                    l10n.paywallBenefit1,
                    l10n.paywallBenefit2,
                    l10n.paywallBenefit3,
                  ].indexed)
                    FadeInLeft(
                      from: 16,
                      delay: Duration(milliseconds: 120 * (i + 1)),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '—',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.brass,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                text,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (!configured)
                    InlineNotice(
                      key: const Key('paywall-dev-notice'),
                      kind: StatusKind.warning,
                      message:
                          '${l10n.paywallDevNoticeTitle}. ${l10n.paywallDevNotice}',
                    )
                  else if (busy == PaywallBusy.loadingPackages)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Semantics(
                      container: true,
                      label: l10n.paywallOptions,
                      child: Column(
                        children: [
                          if (subscription != null)
                            _PlanTile(
                              package: subscription!,
                              title: l10n.paywallSubscriptionTitle,
                              subtitle: l10n.paywallSubscriptionPerks,
                              priceNote: l10n.paywallPerMonth,
                              selected: subscription!.id == selectedId,
                              onTap: _busy
                                  ? null
                                  : () => onSelect(subscription!.id),
                            ),
                          for (final p in packs)
                            _PlanTile(
                              package: p,
                              title: l10n.packTitle(p.credits ?? 0),
                              subtitle: l10n.paywallPackPerk,
                              selected: p.id == selectedId,
                              onTap: _busy ? null : () => onSelect(p.id),
                            ),
                        ],
                      ),
                    ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    InlineNotice(message: errorMessage!),
                  ],
                  if (pending) ...[
                    const SizedBox(height: 8),
                    InlineNotice(
                      key: const Key('paywall-pending'),
                      kind: StatusKind.warning,
                      message: (_selected?.isPack ?? false)
                          ? l10n.paywallPendingPack
                          : l10n.paywallPending,
                      actionLabel: l10n.paywallCheckAgain,
                      onAction: _busy ? null : onCheckAgain,
                    ),
                  ],
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppButton(
                      key: const Key('subscribe-button'),
                      label: switch (busy) {
                        PaywallBusy.confirming => l10n.paywallConfirming,
                        PaywallBusy.purchasing ||
                        PaywallBusy.restoring => l10n.loading,
                        _ =>
                          (_selected?.isPack ?? false)
                              ? l10n.paywallBuy
                              : l10n.paywallSubscribe,
                      },
                      loading:
                          busy == PaywallBusy.purchasing ||
                          busy == PaywallBusy.confirming ||
                          busy == PaywallBusy.restoring,
                      onPressed: (!configured || _busy || _selected == null)
                          ? null
                          : onPurchase,
                    ),
                    if (hasFree)
                      TextButton(
                        key: const Key('use-free-button'),
                        onPressed: onClose,
                        child: Text(l10n.paywallUseFree),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.paywallLegal,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        height: 1.4,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      key: const Key('restore-button'),
                      onPressed: (!configured || _busy) ? null : onRestore,
                      child: Text(l10n.paywallRestore),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.package,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.priceNote,
  });

  final PaywallPackage package;
  final String title;
  final String subtitle;
  final String? priceNote;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        selected: selected,
        button: true,
        child: InkWell(
          key: Key('package-${package.id}'),
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: scheme.surfaceContainerLowest,
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? scheme.primary : scheme.outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      package.priceString,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: appFigures,
                      ),
                    ),
                    if (priceNote != null)
                      Text(
                        priceNote!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
