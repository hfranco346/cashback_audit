import 'package:flutter/material.dart';

import '../../l10n/l10n_context.dart';
import '../../theme/app_theme.dart';

/// The single yellow notice that replaces several stacked warnings. Shows a
/// summary and expands to the full list of [messages].
class CollapsibleWarning extends StatefulWidget {
  const CollapsibleWarning({
    super.key,
    required this.title,
    required this.messages,
    this.initiallyExpanded = false,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final List<String> messages;
  final bool initiallyExpanded;

  /// Optional action shown under the messages when expanded.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<CollapsibleWarning> createState() => _CollapsibleWarningState();
}

class _CollapsibleWarningState extends State<CollapsibleWarning> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final tone = context.appColors.warning;
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: tone.fg,
      fontWeight: FontWeight.w600,
      fontSize: 12,
      height: 1.4,
    );
    return Material(
      color: tone.bg,
      borderRadius: BorderRadius.circular(AppRadii.field),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            hint: _expanded ? l10n.hideDetails : l10n.showDetails,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: tone.fg,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(widget.title, style: style)),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.expand_more_rounded,
                          size: 22,
                          color: tone.fg,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(40, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final m in widget.messages)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(m, style: style),
                          ),
                        if (widget.actionLabel != null &&
                            widget.onAction != null)
                          TextButton(
                            onPressed: widget.onAction,
                            style: TextButton.styleFrom(
                              foregroundColor: tone.fg,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(48, 40),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: style?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            child: Text(widget.actionLabel!),
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
