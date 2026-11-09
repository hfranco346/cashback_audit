import 'package:cashback_audit/core/ui/ui.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

/// Every design-system component on one scrolling page (smoke test + manual
/// visual check).
class UiGallery extends StatelessWidget {
  const UiGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Palette', caption: true),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              StatusPill(kind: StatusKind.ok, label: 'In category'),
              StatusPill(kind: StatusKind.error, label: 'No category'),
              StatusPill(kind: StatusKind.overpaid, label: 'Overpaid'),
              StatusPill(kind: StatusKind.warning, label: 'Notice'),
              StatusPill(kind: StatusKind.neutral, label: 'Excluded'),
            ],
          ),
          const SizedBox(height: 16),
          const CreditCardView(
            alias: 'BAC Cash',
            last4: '4821',
            currency: 'HNL',
            rewardLabel: 'CASHBACK',
            subtitle: 'BAC Credomatic · base 0% · 2 rules',
          ),
          const SizedBox(height: 16),
          const VerdictCard(
            kind: StatusKind.error,
            statusIcon: Icons.arrow_downward_rounded,
            statusLabel: 'Underpaid',
            title: 'You were underpaid',
            amount: '–HNL 1,526.84',
            expectedLabel: 'Expected',
            expected: 'HNL 1,526.84',
            reportedLabel: 'Reported',
            reported: 'HNL 0.00',
            equivalence: 'Equivalent to USD 58.70',
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                MovementRow(
                  kind: StatusKind.ok,
                  name: 'Supermercados Del Corral',
                  bankText: 'SUPERMERCADOS DEL CORRAL COMAYAGUA HN',
                  statusText: 'In category · Groceries 7% · AI',
                  amount: 'HNL 1,140.56',
                  reward: '+HNL 79.84',
                ),
                MovementRow(
                  kind: StatusKind.error,
                  name: 'Comidas Especiales Eberso',
                  statusText: 'No category · base rate 0%',
                  amount: 'HNL 297.86',
                  onAssignCategory: () {},
                ),
                const MovementRow(
                  kind: StatusKind.neutral,
                  name: 'Payment received',
                  statusText: 'Excluded · card payment',
                  amount: '–HNL 68,531.56',
                  showDivider: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const RateField(
            title: 'Groceries',
            source: RateSource.detected,
            quote: 'Earn Cash Back on purchases 7% Groceries',
          ),
          const SizedBox(height: 8),
          const RateField(title: 'Base rate', source: RateSource.cardRules),
          const SizedBox(height: 8),
          const RateField(
            title: 'Fuel',
            source: RateSource.required,
            errorText: 'Enter the percentage to continue',
          ),
          const SizedBox(height: 16),
          FilterSegmented<int>(
            selected: 0,
            onChanged: (_) {},
            options: const [
              FilterOption(value: 0, label: 'All', count: 52),
              FilterOption(value: 1, label: 'Category', count: 26),
              FilterOption(value: 2, label: 'None', count: 12),
              FilterOption(value: 3, label: 'Excl.', count: 14),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              AppChip(label: 'BAC Cash', selected: true, onTap: () {}),
              AppChip(label: 'Ficohsa Signature', onTap: () {}),
            ],
          ),
          const SizedBox(height: 12),
          const CollapsibleWarning(
            title: '2 notices',
            messages: [
              '8 USD purchases without exchange rate were left out.',
              'The statement total does not match.',
            ],
          ),
          const SizedBox(height: 16),
          const StepProgress(step: 2),
          const SizedBox(height: 16),
          AmountText(amount: Decimal.parse('1526.84'), currency: 'HNL'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppButton(label: 'Check', onPressed: () {}),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton.ghost(label: 'History', onPressed: () {}),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
