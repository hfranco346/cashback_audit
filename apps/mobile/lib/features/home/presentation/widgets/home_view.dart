import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../shared/widgets/atoms/section_header.dart';
import '../../../../shared/widgets/atoms/staggered_entrance.dart';
import '../../../../shared/widgets/molecules/empty_state.dart';
import '../../../../shared/widgets/molecules/inline_message.dart';
import '../../../cards/domain/card_entities.dart';
import '../../../cards/presentation/widgets/card_tile.dart';

/// Pure presentational home screen. [extraSections] lets later features
/// (latest verifications) plug in below the cards without touching this file.
class HomeView extends StatelessWidget {
  const HomeView({
    super.key,
    required this.greeting,
    required this.cards,
    required this.loading,
    required this.offline,
    required this.onRefresh,
    required this.onAddCard,
    required this.onOpenCard,
    required this.onLongPressCard,
    required this.onOpenCatalog,
    required this.onOpenSettings,
    this.errorMessage,
    this.quickActions = const [],
    this.extraSections = const [],
  });

  final String greeting;
  final List<CreditCard> cards;
  final bool loading;
  final bool offline;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final VoidCallback onAddCard;
  final ValueChanged<CreditCard> onOpenCard;
  final ValueChanged<CreditCard> onLongPressCard;
  final VoidCallback onOpenCatalog;
  final VoidCallback onOpenSettings;
  final List<Widget> quickActions;
  final List<Widget> extraSections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showEmpty = cards.isEmpty && !loading && errorMessage == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(greeting),
        actions: [
          IconButton(
            tooltip: S.manageCategories,
            onPressed: onOpenCatalog,
            icon: const Icon(Icons.category_outlined),
          ),
          IconButton(
            tooltip: S.settingsTitle,
            onPressed: onOpenSettings,
            icon: const Icon(Icons.person_outline_rounded),
          ),
        ],
      ),
      floatingActionButton: cards.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: onAddCard,
              icon: const Icon(Icons.add_card_rounded),
              label: const Text(S.addCard),
            ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (offline)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: InlineMessage(
                    message: S.offlineBanner,
                    tone: InlineMessageTone.info,
                  ),
                ),
              ),
            if (errorMessage != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: InlineMessage(
                    message: errorMessage!,
                    actionLabel: S.retry,
                    onAction: () => onRefresh(),
                  ),
                ),
              ),
            if (quickActions.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Row(
                    children: [
                      for (var i = 0; i < quickActions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(child: quickActions[i]),
                      ],
                    ],
                  ),
                ),
              ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 10),
                child: SectionHeader(title: S.homeCards),
              ),
            ),
            if (loading && cards.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (showEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.credit_card_rounded,
                  title: S.homeNoCardsTitle,
                  message: S.homeNoCardsBody,
                  actionLabel: S.addCard,
                  onAction: onAddCard,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.separated(
                  itemCount: cards.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => StaggeredEntrance(
                    index: i,
                    child: CardTile(
                      card: cards[i],
                      onTap: () => onOpenCard(cards[i]),
                      onLongPress: () => onLongPressCard(cards[i]),
                    ),
                  ),
                ),
              ),
            ...extraSections,
            SliverToBoxAdapter(
              child: SizedBox(
                height: 96,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      cards.isEmpty ? '' : S.longPressHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
