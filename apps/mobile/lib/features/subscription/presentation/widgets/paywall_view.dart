import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../shared/widgets/molecules/inline_message.dart';
import '../../domain/subscription_entities.dart';
import '../paywall_controller.dart' show PaywallBusy;

/// Pure presentational paywall.
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

  /// Free verifications the user still has (first-free messaging).
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: onClose,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          ZoomIn(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: scheme.onPrimary,
                  size: 38,
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
          FadeInUp(
            child: Text(
              S.paywallHeadline,
              style: theme.textTheme.headlineMedium,
            ),
          ),
          SizedBox(height: 18),
          for (final (i, text) in [
            S.paywallBenefit1,
            S.paywallBenefit2,
            S.paywallBenefit3,
          ].indexed)
            FadeInLeft(
              delay: Duration(milliseconds: 120 * (i + 1)),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_rounded, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(text, style: theme.textTheme.bodyLarge),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          if (freeCredits > 0) ...[
            InlineMessage(
              key: const Key('paywall-free-banner'),
              message: S.paywallFreeBanner(freeCredits),
              tone: InlineMessageTone.info,
            ),
            const SizedBox(height: 16),
          ],
          if (!configured)
            InlineMessage(
              key: Key('paywall-dev-notice'),
              message: '${S.paywallDevNoticeTitle}. ${S.paywallDevNotice}',
              tone: InlineMessageTone.warning,
            )
          else if (busy == PaywallBusy.loadingPackages)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (subscription != null)
              _PackageTile(
                package: subscription!,
                title: S.paywallSubscriptionTitle,
                subtitle: S.paywallSubscriptionPerks,
                selected: subscription!.id == selectedId,
                onTap: _busy ? null : () => onSelect(subscription!.id),
              ),
            if (packs.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(S.paywallPacksTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                S.paywallPacksSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              for (final p in packs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PackageTile(
                    package: p,
                    title: S.packTitle(p.credits ?? 0),
                    selected: p.id == selectedId,
                    onTap: _busy ? null : () => onSelect(p.id),
                  ),
                ),
            ],
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            InlineMessage(message: errorMessage!),
          ],
          if (pending) ...[
            const SizedBox(height: 8),
            InlineMessage(
              key: const Key('paywall-pending'),
              message: (_selected?.isPack ?? false)
                  ? S.paywallPendingPack
                  : S.paywallPending,
              tone: InlineMessageTone.info,
              actionLabel: S.paywallCheckAgain,
              onAction: _busy ? null : onCheckAgain,
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('subscribe-button'),
            onPressed: (!configured || _busy || _selected == null)
                ? null
                : onPurchase,
            child: switch (busy) {
              PaywallBusy.purchasing ||
              PaywallBusy.confirming ||
              PaywallBusy.restoring => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    busy == PaywallBusy.confirming
                        ? S.paywallConfirming
                        : S.loading,
                  ),
                ],
              ),
              _ => Text(
                (_selected?.isPack ?? false)
                    ? S.paywallBuy
                    : S.paywallSubscribe,
              ),
            },
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('restore-button'),
            onPressed: (!configured || _busy) ? null : onRestore,
            child: Text(S.paywallRestore),
          ),
          const SizedBox(height: 8),
          Text(
            S.paywallLegal,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({
    required this.package,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final PaywallPackage package;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      key: Key('package-${package.id}'),
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected ? scheme.primaryContainer : null,
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
              color: scheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  if (subtitle != null)
                    Text(subtitle!, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Text(package.priceString, style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
