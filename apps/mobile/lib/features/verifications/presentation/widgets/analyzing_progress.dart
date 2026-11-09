import 'dart:async';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';

/// Expectation-setting progress for the ~1 minute analysis. The backend is a
/// single request, so the steps advance with elapsed time: reading the
/// statement first, then classifying the movements.
class AnalyzingProgress extends StatefulWidget {
  const AnalyzingProgress({
    super.key,
    this.readSeconds = 25,
    this.tick = const Duration(seconds: 1),
  });

  /// Seconds after which the "reading" step is shown as done.
  final int readSeconds;
  final Duration tick;

  @override
  State<AnalyzingProgress> createState() => _AnalyzingProgressState();
}

class _AnalyzingProgressState extends State<AnalyzingProgress> {
  Timer? _timer;
  int _elapsed = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.tick, (_) {
      if (mounted) setState(() => _elapsed++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reading = _elapsed < widget.readSeconds;
    return Column(
      key: const Key('analyzing-progress'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Step(
          key: Key('step-upload'),
          label: S.analyzingStepUpload,
          state: _StepState.done,
        ),
        _Step(
          key: const Key('step-read'),
          label: S.analyzingStepRead,
          state: reading ? _StepState.active : _StepState.done,
        ),
        _Step(
          key: const Key('step-classify'),
          label: S.analyzingStepClassify,
          state: reading ? _StepState.pending : _StepState.active,
        ),
        const SizedBox(height: 12),
        Text(S.analyzingExpect, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

enum _StepState { pending, active, done }

class _Step extends StatelessWidget {
  const _Step({super.key, required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final icon = switch (state) {
      _StepState.done => Icon(
        Icons.check_circle_rounded,
        color: scheme.primary,
        size: 22,
      ),
      _StepState.active => Pulse(
        infinite: true,
        child: Icon(Icons.autorenew_rounded, color: scheme.primary, size: 22),
      ),
      _StepState.pending => Icon(
        Icons.radio_button_unchecked_rounded,
        color: scheme.outline,
        size: 22,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: state == _StepState.pending
                    ? scheme.onSurfaceVariant
                    : scheme.onSurface,
                fontWeight: state == _StepState.active
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
