import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../auth/domain/auth_entities.dart';
import '../../../credits/domain/credit_entities.dart';
import '../../../subscription/domain/subscription_entities.dart';
import '../../domain/locale_preference.dart';
import '../../domain/theme_preference.dart';
import 'profile_credits_card.dart';
import 'settings_rows.dart';

/// Pure presentational "Perfil" tab: account, credit balance, shortcuts,
/// appearance and sign-out.
class SettingsView extends StatelessWidget {
  const SettingsView({
    super.key,
    required this.user,
    required this.balance,
    required this.subscription,
    required this.language,
    required this.currencies,
    required this.theme,
    required this.onGetMore,
    required this.onCreditHistory,
    required this.onRestore,
    required this.onLanguageCurrencies,
    required this.onTheme,
    required this.onSignOut,
  });

  final AppUser? user;
  final CreditBalance? balance;
  final SubscriptionStatus? subscription;
  final LocalePreference language;

  /// Primary currency first, then the rest.
  final List<String> currencies;
  final ThemePreference theme;
  final VoidCallback onGetMore;
  final VoidCallback onCreditHistory;
  final VoidCallback onRestore;
  final VoidCallback onLanguageCurrencies;
  final ValueChanged<ThemePreference> onTheme;
  final VoidCallback onSignOut;

  static String initials(AppUser? user) {
    final source = (user?.name?.trim().isNotEmpty ?? false)
        ? user!.name!.trim()
        : (user?.email ?? '?');
    final parts = source
        .split(RegExp(r'[\s@._-]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final letters = parts.length == 1
        ? parts.first.characters.first
        : parts.first.characters.first + parts[1].characters.first;
    return letters.toUpperCase();
  }

  String _languageName(BuildContext context) => switch (language) {
    LocalePreference.auto =>
      '${context.l10n.languageAutomatic} · '
          '${Localizations.localeOf(context).languageCode == 'en' ? context.l10n.languageEnglish : context.l10n.languageSpanish}',
    LocalePreference.es => context.l10n.languageSpanish,
    LocalePreference.en => context.l10n.languageEnglish,
  };

  String _subscriptionLabel(BuildContext context) {
    final l10n = context.l10n;
    return switch (subscription?.state) {
      SubscriptionState.active => l10n.subscriptionActive,
      SubscriptionState.cancelled => l10n.subscriptionCancelled,
      SubscriptionState.billingIssue => l10n.subscriptionBillingIssue,
      SubscriptionState.expired => l10n.subscriptionExpired,
      _ => l10n.profileNoPlan,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final provider = switch (user?.provider) {
      'GOOGLE' => 'Google',
      'APPLE' => 'Apple',
      _ => null,
    };
    final email = user?.email;
    final subtitle = email == null
        ? null
        : provider == null
        ? email
        : l10n.profileProviderLine(email, provider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            FadeInDown(
              from: 12,
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      initials(user),
                      key: const Key('profile-initials'),
                      style: textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            user?.name ?? email ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.headlineSmall?.copyWith(
                              fontSize: 26,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (subtitle != null && user?.name != null)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FadeInUp(
              from: 14,
              child: ProfileCreditsCard(balance: balance, onGetMore: onGetMore),
            ),
            const SizedBox(height: 14),
            SettingsGroup(
              children: [
                SettingsRow(
                  key: const Key('row-credit-history'),
                  label: l10n.profileCreditHistory,
                  chevron: true,
                  onTap: onCreditHistory,
                ),
                SettingsRow(
                  key: const Key('row-subscription'),
                  label: l10n.profileSubscription,
                  value: _subscriptionLabel(context),
                ),
                SettingsRow(
                  key: const Key('restore-purchases'),
                  label: l10n.paywallRestore,
                  onTap: onRestore,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SettingsGroup(
              children: [
                SettingsRow(
                  key: const Key('row-language'),
                  label: l10n.profileLanguage,
                  value: _languageName(context),
                  chevron: true,
                  onTap: onLanguageCurrencies,
                ),
                SettingsRow(
                  key: const Key('row-currencies'),
                  label: l10n.profileCurrencies,
                  value: currencies.isEmpty ? '—' : currencies.join(' · '),
                  chevron: true,
                  onTap: onLanguageCurrencies,
                ),
              ],
            ),
            const SizedBox(height: 18),
            SectionHeader(title: l10n.appearanceTitle, caption: true),
            const SizedBox(height: 8),
            AppSegmented<ThemePreference>(
              key: const Key('theme-selector'),
              selected: theme,
              onChanged: onTheme,
              options: [
                SegmentOption(
                  value: ThemePreference.system,
                  label: l10n.themeSystem,
                ),
                SegmentOption(
                  value: ThemePreference.light,
                  label: l10n.themeLight,
                ),
                SegmentOption(
                  value: ThemePreference.dark,
                  label: l10n.themeDark,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('logout'),
                onPressed: onSignOut,
                style: TextButton.styleFrom(
                  foregroundColor: context.appColors.error.fg,
                  minimumSize: const Size(48, 48),
                  padding: EdgeInsets.zero,
                  textStyle: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                child: Text(l10n.logout),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
