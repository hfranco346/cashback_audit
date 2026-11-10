import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../cards/domain/card_entities.dart';
import '../../../cards/domain/card_validator.dart';
import '../onboarding_controller.dart';
import 'onboarding_frame.dart';

Widget _skip(BuildContext context, OnboardingController c) => TextButton(
  key: const Key('onb-skip'),
  onPressed: c.skipSetup,
  child: Text(context.l10n.skip),
);

Widget _continue(BuildContext context, OnboardingController c) => Obx(
  () => AppButton(
    key: const Key('onb-continue'),
    label: context.l10n.continueLabel,
    onPressed: c.canContinue ? c.next : null,
  ),
);

/// Step 1: the bank.
class BankStep extends StatefulWidget {
  const BankStep({super.key, required this.controller});

  final OnboardingController controller;

  @override
  State<BankStep> createState() => _BankStepState();
}

class _BankStepState extends State<BankStep> {
  final _search = TextEditingController();
  final _other = TextEditingController();
  bool _otherSelected = false;

  OnboardingController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    final bank = c.draft.value.bank;
    if (bank.isNotEmpty && !onboardingBanks.any((b) => b.name == bank)) {
      _otherSelected = true;
      _other.text = bank;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _other.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return OnboardingFrame(
      step: 1,
      stepName: l10n.onbStepBank,
      onBack: c.back,
      trailing: _skip(context, c),
      footer: _continue(context, c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnboardingTitle(title: l10n.onbBankTitle, subtitle: l10n.onbBankSub),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            key: const Key('onb-bank-search'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: l10n.onbBankSearch,
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Obx(() {
            final selected = c.draft.value.bank;
            final q = _search.text.trim().toLowerCase();
            final banks = [
              for (final b in onboardingBanks)
                if (q.isEmpty || b.name.toLowerCase().contains(q)) b,
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final b in banks) ...[
                  OptionTile(
                    key: Key('bank-${b.name}'),
                    label: b.name,
                    selected: !_otherSelected && selected == b.name,
                    onTap: () {
                      setState(() => _otherSelected = false);
                      c.selectBank(b.name);
                    },
                    trailing: b.tested
                        ? StatusPill(
                            kind: StatusKind.ok,
                            label: l10n.onbBankTested,
                          )
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                OptionTile(
                  key: const Key('bank-other'),
                  label: l10n.onbBankOther,
                  selected: _otherSelected,
                  onTap: () {
                    setState(() => _otherSelected = true);
                    c.setBankOther(_other.text);
                  },
                ),
                if (_otherSelected) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    key: const Key('onb-bank-other-name'),
                    controller: _other,
                    onChanged: c.setBankOther,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l10n.onbBankOtherName,
                    ),
                  ),
                ],
              ],
            );
          }),
          SizedBox(
            height: AppSpacing.sm,
            child: Container(color: theme.canvasColor.withValues(alpha: 0)),
          ),
        ],
      ),
    );
  }
}

/// Step 2: name, last 4, reward kind and currency of the card.
class CardStep extends StatefulWidget {
  const CardStep({super.key, required this.controller});

  final OnboardingController controller;

  @override
  State<CardStep> createState() => _CardStepState();
}

class _CardStepState extends State<CardStep> {
  late final TextEditingController _alias;
  late final TextEditingController _last4;

  OnboardingController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    final d = c.draft.value;
    _alias = TextEditingController(text: d.alias);
    _last4 = TextEditingController(text: d.last4);
  }

  @override
  void dispose() {
    _alias.dispose();
    _last4.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelLarge?.copyWith(fontSize: 13);
    return OnboardingFrame(
      step: 2,
      stepName: l10n.onbStepCard,
      onBack: c.back,
      trailing: _skip(context, c),
      footer: _continue(context, c),
      child: Obx(() {
        final d = c.draft.value;
        final isPoints = d.rewardUnit == RewardUnit.points;
        final currency = d.currency ?? '';
        final shortBank = d.bank.split(' ').first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OnboardingTitle(title: l10n.onbCardTitle(shortBank)),
            const SizedBox(height: AppSpacing.lg),
            FadeInUp(
              delay: const Duration(milliseconds: 100),
              from: 14,
              child: CreditCardView(
                alias: c.cardName.isEmpty ? l10n.onbStepCard : c.cardName,
                last4: d.last4.padRight(4, '·'),
                currency: currency.isEmpty ? '···' : currency,
                rewardLabel: isPoints
                    ? l10n.onbRewardLabelPoints
                    : l10n.onbRewardLabelCashback,
                subtitle: d.bank,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.onbCardName, style: labelStyle),
                      const SizedBox(height: 6),
                      TextField(
                        key: const Key('onb-card-name'),
                        controller: _alias,
                        onChanged: c.setAlias,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(hintText: d.bank),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.onbCardLast4, style: labelStyle),
                      const SizedBox(height: 6),
                      TextField(
                        key: const Key('onb-card-last4'),
                        controller: _last4,
                        onChanged: c.setLast4,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        style: const TextStyle(fontFeatures: appFigures),
                        decoration: const InputDecoration(prefixText: '•••• '),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.onbCardLast4Note,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.onbRewardKind, style: labelStyle),
            const SizedBox(height: AppSpacing.sm),
            AppSegmented<RewardUnit>(
              options: [
                SegmentOption(
                  value: RewardUnit.cashbackCurrency,
                  label: l10n.onbRewardCashback,
                ),
                SegmentOption(
                  value: RewardUnit.points,
                  label: l10n.onbRewardPoints,
                ),
              ],
              selected: d.rewardUnit,
              onChanged: c.setUnit,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.onbRewardCurrency, style: labelStyle),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final code in onboardingCurrencies)
                  AppChip(
                    key: Key('currency-$code'),
                    label: code,
                    selected: d.currency == code,
                    onTap: () => c.setCurrency(code),
                  ),
                AppChip(
                  key: const Key('currency-detect'),
                  label: l10n.onbCurrencyDetect,
                  selected: d.currency == null,
                  onTap: () => c.setCurrency(null),
                ),
              ],
            ),
            if (CardValidator.last4(d.last4) != null && d.last4.isNotEmpty)
              const SizedBox.shrink(),
          ],
        );
      }),
    );
  }
}

/// Step 3: categories with their percentage and the base rate.
class CategoriesStep extends StatefulWidget {
  const CategoriesStep({super.key, required this.controller});

  final OnboardingController controller;

  @override
  State<CategoriesStep> createState() => _CategoriesStepState();
}

class _CategoriesStepState extends State<CategoriesStep> {
  final _rates = <String, TextEditingController>{};
  late final TextEditingController _base;
  final _custom = <String>[];

  OnboardingController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _base = TextEditingController(text: c.draft.value.baseRate);
    // Categories typed earlier stay visible when coming back to the step.
    for (final cat in c.draft.value.categories) {
      _rates[cat.name] = TextEditingController(text: cat.rate);
    }
    // The design prefills the common categories; done after the first frame
    // because it changes observable state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l10n = context.l10n;
      c.seedCategories([l10n.onbCatSupermarkets, l10n.onbCatPharmacy]);
    });
  }

  @override
  void dispose() {
    for (final t in _rates.values) {
      t.dispose();
    }
    _base.dispose();
    super.dispose();
  }

  TextEditingController _rateField(String name) => _rates.putIfAbsent(
    name,
    () => TextEditingController(
      text: c.draft.value.categories
          .where((x) => x.name == name)
          .map((x) => x.rate)
          .firstOrNull,
    ),
  );

  Future<void> _addOther() async {
    final l10n = context.l10n;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _CustomCategoryDialog(),
    );
    final clean = name?.trim() ?? '';
    if (clean.isEmpty || !mounted) return;
    setState(() {
      if (!_suggested(l10n).contains(clean) && !_custom.contains(clean)) {
        _custom.add(clean);
      }
    });
    if (!c.isSelected(clean)) c.toggleCategory(clean);
  }

  List<String> _suggested(dynamic l10n) => [
    l10n.onbCatSupermarkets as String,
    l10n.onbCatPharmacy as String,
    l10n.onbCatRestaurants as String,
    l10n.onbCatGas as String,
    l10n.onbCatDepartment as String,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final names = [
      ..._suggested(l10n),
      // Custom ones, including those restored from the saved draft.
      ..._custom,
      for (final cat in c.draft.value.categories)
        if (!_suggested(l10n).contains(cat.name) && !_custom.contains(cat.name))
          cat.name,
    ];
    Widget pct(
      TextEditingController t,
      ValueChanged<String> onChanged,
      Key key,
    ) => SizedBox(
      width: 76,
      child: TextField(
        key: key,
        controller: t,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(
          fontFeatures: appFigures,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Theme.of(context).scaffoldBackgroundColor,
          suffixText: '%',
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 12,
          ),
          errorText: null,
          hintText: '–',
        ),
      ),
    );
    return OnboardingFrame(
      step: 3,
      stepName: l10n.onbStepCategories,
      onBack: c.back,
      trailing: _skip(context, c),
      footer: _continue(context, c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnboardingTitle(
            title: l10n.onbCatsTitle,
            subtitle: l10n.onbCatsSub,
            gap: 14,
          ),
          const SizedBox(height: 14),
          Obx(() {
            // Rebuild on any draft change (selection and typed rates).
            c.draft.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final name in names) ...[
                  OptionTile(
                    key: Key('cat-$name'),
                    label: name,
                    checkbox: true,
                    selected: c.isSelected(name),
                    onTap: () {
                      // A re-ticked category starts blank, like its draft.
                      if (!c.isSelected(name)) _rates[name]?.clear();
                      c.toggleCategory(name);
                    },
                    trailing: c.isSelected(name)
                        ? pct(
                            _rateField(name),
                            (v) => c.setCategoryRate(name, v),
                            Key('cat-rate-$name'),
                          )
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('onb-add-category'),
              onPressed: _addOther,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.onbCatOther),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.onbBaseTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.onbBaseSub,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  pct(_base, c.setBaseRate, const Key('onb-base-rate')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks for the name of an extra category. Owns its text controller so it is
/// disposed only after the dialog is gone.
class _CustomCategoryDialog extends StatefulWidget {
  const _CustomCategoryDialog();

  @override
  State<_CustomCategoryDialog> createState() => _CustomCategoryDialogState();
}

class _CustomCategoryDialogState extends State<_CustomCategoryDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.onbCatOther),
      content: TextField(
        key: const Key('onb-custom-category'),
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: l10n.onbCatOtherName),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('onb-custom-category-add'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.onbCatAdd),
        ),
      ],
    );
  }
}
