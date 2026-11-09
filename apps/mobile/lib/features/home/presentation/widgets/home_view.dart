import 'package:animate_do/animate_do.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/active_locale.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/decimal_utils.dart';
import '../../../cards/domain/card_entities.dart';
import '../../../verifications/domain/verification_entities.dart';
import '../../../verifications/presentation/format_reward.dart';
import '../home_controller.dart';
import 'pending_banner.dart';

/// Pure presentational Home (inside the navigation shell, no FAB). Renders
/// the three designed states plus the pending-verification banners.
class HomeView extends StatelessWidget {
  const HomeView({
    super.key,
    required this.layout,
    required this.greeting,
    required this.initials,
    required this.cards,
    required this.latest,
    required this.pending,
    required this.cardLabel,
    required this.categoryName,
    required this.onRefresh,
    required this.onProfile,
    required this.onVerify,
    required this.onAddCard,
    required this.onOpenCard,
    required this.onOpenVerification,
    required this.onOpenPending,
    required this.onSeeAll,
    required this.onGetMore,
    required this.onGuidedSetup,
    this.freeChecks,
    this.totalChecks,
    this.uncategorized = 0,
    this.firstName,
    this.offline = false,
    this.errorMessage,
    this.onOpenUncategorized,
  });

  final HomeLayout layout;
  final String greeting;
  final String initials;
  final String? firstName;
  final List<CreditCard> cards;
  final List<VerificationSummary> latest;
  final List<VerificationSummary> pending;
  final String Function(String cardId) cardLabel;
  final String Function(String categoryId) categoryName;
  final int? freeChecks;
  final int? totalChecks;
  final int uncategorized;
  final bool offline;
  final String? errorMessage;

  final Future<void> Function() onRefresh;
  final VoidCallback onProfile;
  final VoidCallback onVerify;
  final VoidCallback onAddCard;
  final ValueChanged<CreditCard> onOpenCard;
  final ValueChanged<VerificationSummary> onOpenVerification;
  final ValueChanged<VerificationSummary> onOpenPending;
  final VoidCallback onSeeAll;
  final VoidCallback onGetMore;
  final VoidCallback onGuidedSetup;
  final VoidCallback? onOpenUncategorized;

  static String period(VerificationSummary s) {
    final f = DateFormat.yMMMd(ActiveLocale.intlName);
    final st = s.statement;
    if (st.periodStart != null && st.periodEnd != null) {
      return '${f.format(st.periodStart!)} – ${f.format(st.periodEnd!)}';
    }
    return f.format(s.createdAt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final children = <Widget>[
      if (offline)
        _Notice(text: l10n.homeOffline, icon: Icons.cloud_off_rounded),
      if (errorMessage != null)
        _Notice(
          text: errorMessage!,
          icon: Icons.error_outline_rounded,
          action: l10n.retry,
          onAction: onRefresh,
        ),
      for (final item in pending)
        PendingBanner(
          item: item,
          cardLabel: cardLabel(item.cardId),
          onTap: () => onOpenPending(item),
        ),
      ...switch (layout) {
        HomeLayout.loading => const [
          Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
        HomeLayout.empty => _empty(context),
        HomeLayout.fresh => _fresh(context),
        HomeLayout.full => _full(context),
      },
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          l10n.homeTitle,
                          style: theme.textTheme.headlineLarge,
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: l10n.homeProfileAria,
                    child: InkWell(
                      key: const Key('home-profile'),
                      customBorder: const CircleBorder(),
                      onTap: onProfile,
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.surfaceContainerLowest,
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Text(
                          initials,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: children.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (_, i) => children[i],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- empty: skipped the setup ----

  List<Widget> _empty(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.appColors;
    final muted = theme.colorScheme.onSurfaceVariant;
    Widget step(int n, bool primary, String bold, String rest) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primary ? theme.colorScheme.primary : null,
            border: primary
                ? null
                : Border.all(
                    color: theme.colorScheme.outlineVariant,
                    width: 1.5,
                  ),
          ),
          child: Text(
            '$n',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: primary ? theme.colorScheme.onPrimary : null,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: bold,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: rest),
              ],
            ),
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        ),
      ],
    );
    return [
      if ((freeChecks ?? 0) > 0)
        Align(
          alignment: Alignment.centerLeft,
          child: StatusPill(
            kind: StatusKind.ok,
            label: l10n.homeFreeChecks(freeChecks!),
            icon: Icons.auto_awesome_rounded,
          ),
        ),
      FadeInUp(
        from: 12,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 120,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 30,
                        top: 18,
                        child: Transform.rotate(
                          angle: -0.105,
                          child: Opacity(
                            opacity: 0.45,
                            child: _MiniCard(color: colors.creditCard),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 70,
                        top: 6,
                        child: _MiniCard(
                          color: colors.creditCard,
                          title: l10n.homeEmptyCardPlaceholder,
                          digits: '•••• ····',
                          size: const Size(210, 108),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(l10n.homeEmptyTitle, style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.md),
                step(1, true, l10n.homeStep1Bold, l10n.homeStep1Rest),
                const SizedBox(height: AppSpacing.md),
                step(2, false, l10n.homeStep2Bold, l10n.homeStep2Rest),
                const SizedBox(height: 18),
                AppButton(
                  key: const Key('home-add-card'),
                  label: l10n.homeAddMyCard,
                  onPressed: onAddCard,
                ),
              ],
            ),
          ),
        ),
      ),
      Column(
        children: [
          Icon(Icons.description_outlined, size: 28, color: muted),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.homeNoChecksTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            l10n.homeNoChecksBody,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          TextButton(
            key: const Key('home-guided-setup'),
            onPressed: onGuidedSetup,
            child: Text(l10n.homeGuidedSetup),
          ),
        ],
      ),
    ];
  }

  // ---- fresh: just finished the setup ----

  List<Widget> _fresh(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final card = cards.first;
    final first = latest.firstOrNull;
    return [
      DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_rounded,
                size: 18,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.homeFreshBanner(firstName ?? 'none'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      _verifyBlock(context, used: (freeChecks ?? 1) == 0),
      _Section(
        title: l10n.homeMyCard,
        children: [
          _CardCarousel(
            cards: [card],
            onOpenCard: onOpenCard,
            onAdd: onAddCard,
            addLabel: l10n.homeAddAnotherCard,
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final r in card.rules)
                StatusPill(
                  kind: StatusKind.ok,
                  label:
                      '${categoryName(r.categoryId)} '
                      '${formatRate(r.ratePercent)}',
                ),
              StatusPill(
                kind: StatusKind.neutral,
                label: l10n.homeEverythingElse(
                  formatRate(card.baseRatePercent),
                ),
              ),
            ],
          ),
        ],
      ),
      if (first != null)
        _Section(
          title: l10n.homeFirstVerification,
          children: [
            _VerificationRow(
              summary: first,
              cardLabel: card.alias,
              onTap: () => onOpenVerification(first),
              bordered: true,
            ),
            if (uncategorized > 0)
              Material(
                color: context.appColors.error.bg,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  key: const Key('home-uncategorized'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: onOpenUncategorized ?? () => onOpenVerification(first),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.homeUncategorized(uncategorized),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: context.appColors.error.fg,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: context.appColors.error.fg,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
    ];
  }

  // ---- full: continuous use ----

  List<Widget> _full(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return [
      _verifyBlock(context),
      _Section(
        title: l10n.homeMyCards,
        trailing: Text(
          l10n.homeTapToEdit,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          _CardCarousel(
            cards: cards,
            onOpenCard: onOpenCard,
            onAdd: onAddCard,
            addLabel: l10n.homeAddCardTile,
          ),
        ],
      ),
      _Section(
        title: l10n.homeLatestChecks,
        trailing: TextButton(
          key: const Key('home-see-all'),
          onPressed: onSeeAll,
          child: Text(l10n.homeSeeAll),
        ),
        children: [
          if (latest.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text(
                  l10n.homeNoChecksBody,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < latest.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        color: theme.colorScheme.outlineVariant,
                      ),
                    _VerificationRow(
                      summary: latest[i],
                      cardLabel: cardLabel(latest[i].cardId),
                      onTap: () => onOpenVerification(latest[i]),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    ];
  }

  Widget _verifyBlock(BuildContext context, {bool used = false}) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final total = totalChecks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          key: const Key('home-verify'),
          label: l10n.homeVerifyStatement,
          icon: Icons.upload_rounded,
          onPressed: onVerify,
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Text.rich(
            TextSpan(
              children: [
                if (used)
                  TextSpan(text: '${l10n.homeUsedFree} · ')
                else if (total != null)
                  TextSpan(text: '${l10n.homeChecksAvailable(total)} · '),
              ],
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: muted,
              fontFeatures: appFigures,
            ),
          ),
        ),
        Center(
          child: TextButton(
            key: const Key('home-get-more'),
            onPressed: onGetMore,
            style: TextButton.styleFrom(minimumSize: const Size(48, 36)),
            child: Text(l10n.homeGetMore),
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.text,
    required this.icon,
    this.action,
    this.onAction,
  });

  final String text;
  final IconData icon;
  final String? action;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    final tone = context.appColors.neutral;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: tone.fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: tone.fg, fontWeight: FontWeight.w600),
              ),
            ),
            if (action != null)
              TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.trailing});

  final String title;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title, trailing: trailing),
        const SizedBox(height: 10),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          children[i],
        ],
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.color,
    this.title,
    this.digits,
    this.size = const Size(200, 100),
  });

  final Color color;
  final String? title;
  final String? digits;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final on = context.appColors.onCreditCard;
    return Container(
      width: size.width,
      height: size.height,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.creditCard),
        border: Border.all(
          color: const Color(0xFFCDAE6E).withValues(alpha: 0.45),
        ),
      ),
      child: title == null
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title!,
                  style: text.titleLarge?.copyWith(
                    fontFamily: AppFonts.display,
                    fontSize: 18,
                    height: 1.1,
                    color: on,
                  ),
                ),
                Text(
                  digits ?? '',
                  style: text.bodyMedium?.copyWith(
                    color: on,
                    fontSize: 14,
                    height: 1.1,
                    letterSpacing: 2.8,
                    fontFeatures: appFigures,
                  ),
                ),
              ],
            ),
    );
  }
}

class _CardCarousel extends StatelessWidget {
  const _CardCarousel({
    required this.cards,
    required this.onOpenCard,
    required this.onAdd,
    required this.addLabel,
  });

  final List<CreditCard> cards;
  final ValueChanged<CreditCard> onOpenCard;
  final VoidCallback onAdd;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SizedBox(
      height: 146,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          for (final c in cards) ...[
            SizedBox(
              width: 236,
              child: CreditCardView(
                key: Key('home-card-${c.id}'),
                alias: c.alias,
                last4: c.last4,
                currency: c.currency,
                subtitle: l10n.homeCardMeta(
                  c.bank,
                  formatRate(c.baseRatePercent),
                  l10n.ruleCount(c.rules.length),
                ),
                onTap: () => onOpenCard(c),
              ),
            ),
            const SizedBox(width: 12),
          ],
          SizedBox(
            width: 120,
            child: Semantics(
              button: true,
              child: InkWell(
                key: const Key('home-add-card-tile'),
                borderRadius: BorderRadius.circular(AppRadii.creditCard),
                onTap: onAdd,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.creditCard),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, color: theme.colorScheme.primary),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          addLabel,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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

/// Verification row: card and full period on two lines, amount and status
/// pill on the right (the period is never cut).
class _VerificationRow extends StatelessWidget {
  const _VerificationRow({
    required this.summary,
    required this.cardLabel,
    required this.onTap,
    this.bordered = false,
  });

  final VerificationSummary summary;
  final String cardLabel;
  final VoidCallback onTap;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.appColors;
    final verdict = summary.verdict;
    StatusKind? kind;
    String? label;
    if (verdict != null && summary.isCompleted) {
      kind = switch (verdict) {
        Verdict.match => StatusKind.ok,
        Verdict.underpaid => StatusKind.error,
        Verdict.overpaid => StatusKind.overpaid,
      };
      label = switch (verdict) {
        Verdict.match => l10n.onbVerdictStatusMatch,
        Verdict.underpaid => l10n.onbVerdictStatusUnder,
        Verdict.overpaid => l10n.onbVerdictStatusOver,
      };
    } else {
      kind = switch (summary.status) {
        VerificationStatus.failed => StatusKind.error,
        VerificationStatus.awaitingRates => StatusKind.warning,
        _ => StatusKind.neutral,
      };
      label = switch (summary.status) {
        VerificationStatus.processing => l10n.pendingProcessingTitle,
        VerificationStatus.failed => l10n.pendingFailedTitle,
        _ => l10n.awaitingRatesChip,
      };
    }
    final diff = summary.difference;
    final tone = kind.tone(colors);
    final row = InkWell(
      key: Key('home-verification-${summary.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cardLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    HomeView.period(summary),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: appFigures,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (diff != null && summary.isCompleted)
                  Text(
                    '${diff > Decimal.zero
                        ? '+'
                        : diff < Decimal.zero
                        ? '–'
                        : ''}'
                    '${formatReward(diff.abs(), summary.unit, currency: summary.resolvedRewardCurrency)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: tone.fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFeatures: appFigures,
                    ),
                  ),
                const SizedBox(height: 4),
                StatusPill(kind: kind, label: label),
              ],
            ),
          ],
        ),
      ),
    );
    if (!bordered) return row;
    return Card(clipBehavior: Clip.antiAlias, child: row);
  }
}
