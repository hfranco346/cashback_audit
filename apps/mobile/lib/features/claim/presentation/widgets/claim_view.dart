import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/claim_email.dart';

/// Pure presentational "Claim to the bank" screen (`Reclamo.dc.html`).
class ClaimView extends StatelessWidget {
  const ClaimView({
    super.key,
    required this.summary,
    required this.language,
    required this.onLanguage,
    required this.tone,
    required this.onTone,
    required this.toField,
    required this.email,
    required this.onBack,
    required this.onCopy,
    required this.onOpenMail,
    this.busy = false,
  });

  /// `BAC Cash •••• 4821 · 3 oct – 3 nov 2026 · –HNL 1,526.84`.
  final String summary;
  final ClaimLanguage language;
  final ValueChanged<ClaimLanguage> onLanguage;
  final ClaimTone tone;
  final ValueChanged<ClaimTone> onTone;
  final TextEditingController toField;
  final ClaimEmail email;
  final VoidCallback onBack;
  final VoidCallback onCopy;
  final VoidCallback onOpenMail;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final lang = language.name;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
          child: Row(
            children: [
              IconButton(
                key: const Key('claim-back'),
                tooltip: l10n.back,
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Text(
                  l10n.claimTitle,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.sm,
              AppSpacing.screen,
              AppSpacing.lg,
            ),
            children: [
              Text(
                summary,
                key: const Key('claim-summary'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  fontFeatures: appFigures,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Labeled(
                      label: l10n.claimLanguageLabel,
                      child: AppSegmented<ClaimLanguage>(
                        key: const Key('claim-language'),
                        selected: language,
                        onChanged: onLanguage,
                        options: [
                          SegmentOption(
                            value: ClaimLanguage.es,
                            label: l10n.claimLangEs,
                          ),
                          SegmentOption(
                            value: ClaimLanguage.en,
                            label: l10n.claimLangEn,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Labeled(
                      label: l10n.claimToneLabel,
                      child: AppSegmented<ClaimTone>(
                        key: const Key('claim-tone'),
                        selected: tone,
                        onChanged: onTone,
                        options: [
                          SegmentOption(
                            value: ClaimTone.formal,
                            label: l10n.claimToneFormal,
                          ),
                          SegmentOption(
                            value: ClaimTone.firm,
                            label: l10n.claimToneFirm,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.claimLanguageHelp,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Row(
                      label: l10n.claimToLabel,
                      child: TextField(
                        key: const Key('claim-to'),
                        controller: toField,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textInputAction: TextInputAction.done,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: l10n.claimToHint,
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    _Row(
                      label: l10n.claimSubjectLabel,
                      child: Text(
                        email.subject,
                        key: const Key('claim-subject'),
                        locale: Locale(lang),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        email.body,
                        key: const Key('claim-body'),
                        locale: Locale(lang),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13.5,
                          height: 1.55,
                          fontFeatures: appFigures,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Row(
              children: [
                AppButton.ghost(
                  key: const Key('claim-copy'),
                  label: l10n.claimCopy,
                  icon: Icons.copy_rounded,
                  expand: false,
                  onPressed: busy ? null : onCopy,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    key: const Key('claim-open-mail'),
                    label: l10n.claimOpenMail,
                    icon: Icons.mail_outline_rounded,
                    loading: busy,
                    onPressed: onOpenMail,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// A `label | value` row of the email card, followed by a hairline.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
