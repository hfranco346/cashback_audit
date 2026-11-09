import 'dart:async';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';

/// "Analyzing with AI" block: progress track plus a four-step checklist
/// (card, period, classification, rates). The backend only reports
/// `PROCESSING`, so the steps advance on a timer and the last active one
/// keeps pulsing; nothing here claims real numbers.
class ProcessingChecklist extends StatefulWidget {
  const ProcessingChecklist({
    super.key,
    this.cardLine,
    this.stepDuration = const Duration(seconds: 9),
  });

  /// Detail under the first step, e.g. `BAC Credomatic · ends in 4821`.
  final String? cardLine;
  final Duration stepDuration;

  @override
  State<ProcessingChecklist> createState() => _ProcessingChecklistState();
}

class _ProcessingChecklistState extends State<ProcessingChecklist> {
  static const _lastActive = 2;
  int _active = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.stepDuration, (t) {
      if (_active >= _lastActive) return t.cancel();
      setState(() => _active++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final steps = [
      (l10n.processingStepCard, widget.cardLine),
      (l10n.processingStepPeriod, null),
      (l10n.processingStepClassify, null),
      (l10n.processingStepRates, null),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.processingAnalyzing,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              l10n.processingEta,
              style: theme.textTheme.bodySmall?.copyWith(
                color: muted,
                fontFeatures: appFigures,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: const LinearProgressIndicator(minHeight: 6),
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.lg),
                  _StepRow(
                    key: ValueKey('processing-step-$i'),
                    title: steps[i].$1,
                    detail: steps[i].$2,
                    state: i < _active
                        ? _StepState.done
                        : i == _active
                        ? _StepState.active
                        : _StepState.pending,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _StepState { done, active, pending }

class _StepRow extends StatelessWidget {
  const _StepRow({
    super.key,
    required this.title,
    required this.state,
    this.detail,
  });

  final String title;
  final String? detail;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final marker = switch (state) {
      _StepState.done => const StatusDot(kind: StatusKind.ok, size: 24),
      _StepState.active => Pulse(
        infinite: true,
        duration: const Duration(milliseconds: 1400),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: scheme.primary, width: 2),
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
      _StepState.pending => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: scheme.outlineVariant, width: 2),
        ),
      ),
    };
    final pending = state == _StepState.pending;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        marker,
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: 14,
                  fontWeight: pending ? FontWeight.w600 : FontWeight.w700,
                  color: pending ? scheme.onSurfaceVariant : null,
                ),
              ),
              if (detail != null && state != _StepState.pending)
                Text(
                  detail!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
