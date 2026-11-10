import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Scrolling body shared by the stepper steps: a heading and the step's
/// fields on a 20 px screen margin.
class CardStepBody extends StatelessWidget {
  const CardStepBody({
    super.key,
    required this.title,
    required this.children,
    this.formKey,
    this.autovalidate = false,
  });

  final String title;
  final List<Widget> children;

  /// Form that validates this step's fields (null for the review step).
  final GlobalKey<FormState>? formKey;

  /// Show field errors right away (after a failed "Next").
  final bool autovalidate;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ...children,
      ],
    );
    if (formKey == null) return list;
    return Form(
      key: formKey,
      autovalidateMode: autovalidate
          ? AutovalidateMode.always
          : AutovalidateMode.disabled,
      child: list,
    );
  }
}

/// Vertical gap between fields.
const cardFieldGap = SizedBox(height: 16);
