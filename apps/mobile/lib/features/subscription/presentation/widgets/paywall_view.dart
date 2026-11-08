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
    required this.packages,
    required this.selectedId,
    required this.onSelect,
    required this.busy,
    required this.pending,
    required this.onSubscribe,
    required this.onRestore,
    required this.onCheckAgain,
    required this.onClose,
    this.errorMessage,
  });

  final bool configured;
  final List<PaywallPackage> packages;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final PaywallBusy busy;
  final bool pending;
  final String? errorMessage;
  final VoidCallback onSubscribe;
  final VoidCallback onRestore;
  final VoidCallback onCheckAgain;
  final VoidCallback onClose;

  bool get _busy => busy != PaywallBusy.none;

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
          const SizedBox(height: 20),
          FadeInUp(
            child: Text(
              S.paywallHeadline,
              style: theme.textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 18),
          for (final (i, text) in const [
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
          if (!configured)
            const InlineMessage(
              key: Key('paywall-dev-notice'),
              message: '${S.paywallDevNoticeTitle}. ${S.paywallDevNotice}',
              tone: InlineMessageTone.warning,
            )
          else if (busy == PaywallBusy.loadingPackages)
            const Center(child: CircularProgressIndicator())
          else
            for (final p in packages)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PackageTile(
                  package: p,
                  selected: p.id == selectedId,
                  onTap: _busy ? null : () => onSelect(p.id),
                ),
              ),
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            InlineMessage(message: errorMessage!),
          ],
          if (pending) ...[
            const SizedBox(height: 8),
            InlineMessage(
              key: const Key('paywall-pending'),
              message: S.paywallPending,
              tone: InlineMessageTone.info,
              actionLabel: S.paywallCheckAgain,
              onAction: _busy ? null : onCheckAgain,
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('subscribe-button'),
            onPressed: (!configured || _busy || selectedId == null)
                ? null
                : onSubscribe,
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
              _ => const Text(S.paywallSubscribe),
            },
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('restore-button'),
            onPressed: (!configured || _busy) ? null : onRestore,
            child: const Text(S.paywallRestore),
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
    required this.selected,
    required this.onTap,
  });

  final PaywallPackage package;
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
                  Text(package.title, style: theme.textTheme.titleSmall),
                  if (package.description.isNotEmpty)
                    Text(package.description, style: theme.textTheme.bodySmall),
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
