import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../shared/widgets/atoms/section_header.dart';
import '../../../../shared/widgets/atoms/staggered_entrance.dart';
import '../../domain/verification_entities.dart';
import 'verification_summary_tile.dart';

/// Sliver with the latest verifications for the home screen. Renders nothing
/// when there are none.
class LatestVerificationsSection extends StatelessWidget {
  const LatestVerificationsSection({
    super.key,
    required this.items,
    required this.cardLabel,
    required this.onOpen,
    required this.onSeeAll,
  });

  final List<VerificationSummary> items;
  final String Function(String cardId) cardLabel;
  final ValueChanged<VerificationSummary> onOpen;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 12, 10),
            child: SectionHeader(
              title: S.latestVerifications,
              trailing: TextButton(onPressed: onSeeAll, child: Text(S.seeAll)),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => StaggeredEntrance(
              index: i,
              child: VerificationSummaryTile(
                summary: items[i],
                cardLabel: cardLabel(items[i].cardId),
                onTap: () => onOpen(items[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
