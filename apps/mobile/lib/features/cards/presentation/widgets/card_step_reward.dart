import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/card_entities.dart';
import '../../domain/card_validator.dart';
import 'card_step_scaffold.dart';
import 'currency_picker.dart';

/// Step 2: what the card gives (cashback or points), the currency it is paid
/// in, how the bank reports it and the optional card-wide cap per statement.
/// Presentational.
class CardStepReward extends StatelessWidget {
  const CardStepReward({
    super.key,
    required this.formKey,
    required this.autovalidate,
    required this.rewardUnit,
    required this.onUnitChanged,
    required this.pointsFactor,
    required this.rewardCurrency,
    required this.currency,
    required this.rewardCap,
    required this.capUnit,
    required this.rewardReporting,
    required this.onRewardReportingChanged,
    this.userCurrencies = const [],
  });

  final GlobalKey<FormState> formKey;
  final bool autovalidate;
  final RewardUnit rewardUnit;
  final ValueChanged<RewardUnit> onUnitChanged;
  final TextEditingController pointsFactor;
  final TextEditingController rewardCurrency;

  /// Card currency: the unit of the cap.
  final TextEditingController currency;
  final TextEditingController rewardCap;

  /// Unit the cap is written in (currency code or `pts`), live.
  final String Function() capUnit;
  final RewardReporting rewardReporting;
  final ValueChanged<RewardReporting> onRewardReportingChanged;
  final List<String> userCurrencies;

  static final _decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isPoints = rewardUnit == RewardUnit.points;
    return CardStepBody(
      title: l10n.cardStepTitleReward,
      formKey: formKey,
      autovalidate: autovalidate,
      children: [
        AppField(
          label: l10n.cardRewardKindQuestion,
          child: AppSegmented<RewardUnit>(
            key: const Key('unit-selector'),
            options: [
              SegmentOption(
                value: RewardUnit.cashbackCurrency,
                label: l10n.cardUnitCashback,
              ),
              SegmentOption(
                value: RewardUnit.points,
                label: l10n.cardUnitPoints,
              ),
            ],
            selected: rewardUnit,
            onChanged: onUnitChanged,
          ),
        ),
        if (isPoints) ...[
          cardFieldGap,
          AppField(
            label: l10n.pointsPerUnit,
            child: TextFormField(
              key: const Key('field-points-factor'),
              controller: pointsFactor,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [_decimal],
              decoration: AppField.decoration(),
              validator: CardValidator.pointsFactor,
            ),
          ),
        ] else ...[
          cardFieldGap,
          RewardCurrencyField(
            controller: rewardCurrency,
            userCurrencies: userCurrencies,
          ),
        ],
        cardFieldGap,
        RewardReportingField(
          value: rewardReporting,
          onChanged: onRewardReportingChanged,
        ),
        cardFieldGap,
        ListenableBuilder(
          listenable: currency,
          builder: (context, _) {
            final unit = capUnit();
            final example = isPoints ? '1,000 $unit' : '$unit 1,000';
            return AppField(
              label: isPoints
                  ? l10n.cardRewardCapLabelPoints
                  : l10n.cardRewardCapLabel,
              optionalTag: l10n.cardOptionalTag,
              help: l10n.cardRewardCapHelp(example),
              child: TextFormField(
                key: const Key('field-reward-cap'),
                controller: rewardCap,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [_decimal],
                style: const TextStyle(
                  fontFeatures: appFigures,
                  fontWeight: FontWeight.w600,
                ),
                decoration: AppField.decoration(hint: '0', suffix: unit),
                validator: CardValidator.positiveCap,
              ),
            );
          },
        ),
      ],
    );
  }
}

/// "How does your bank report the cashback?": Auto / earned in the month /
/// accumulated balance, as three self-explaining rows.
class RewardReportingField extends StatelessWidget {
  const RewardReportingField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final RewardReporting value;
  final ValueChanged<RewardReporting>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final options = [
      (
        RewardReporting.auto,
        l10n.cardReportingAuto,
        l10n.cardReportingAutoHint,
      ),
      (
        RewardReporting.monthly,
        l10n.cardReportingMonthly,
        l10n.cardReportingMonthlyHint,
      ),
      (
        RewardReporting.cumulative,
        l10n.cardReportingCumulative,
        l10n.cardReportingCumulativeHint,
      ),
    ];
    return AppField(
      key: const Key('reward-reporting-field'),
      label: l10n.cardReportingLabel,
      optionalTag: l10n.cardOptionalTag,
      help: l10n.cardReportingHelp,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.field),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: RadioGroup<RewardReporting>(
          groupValue: value,
          onChanged: (v) {
            if (v != null) onChanged?.call(v);
          },
          child: Column(
            children: [
              for (final (mode, title, hint) in options)
                RadioListTile<RewardReporting>(
                  key: Key('reporting-${mode.name}'),
                  value: mode,
                  dense: true,
                  title: Text(title),
                  subtitle: Text(
                    hint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
