# Feature: redesign-v2 (new visual design, ES/EN, async verification)

## Objective
Implement the Claude Design redesign (`docs/cashback-audit-design/HANDOFF.md`, `BRIEF.md`, `project/*.dc.html`) in the Flutter app, add ES/EN localization with ARB and phone-locale detection, and move the whole statement evaluation to a background job in the backend so the user can upload a PDF, close the app, and later see that a result is pending review.

## Why
The current UI is the MVP look; the designer delivered a complete system (tokens, components, 13 screens, light/dark, ES/EN). Synchronous ~40 s uploads force the user to keep the app open.

## Scope
- Backend (apps/api): async verification lifecycle, pending/attention endpoint, "seen" marker, user preferences (locale, primary currency, currencies), credit history endpoint if missing.
- Mobile (apps/mobile): theme (ColorScheme light/dark + status ThemeExtension), atomic components, ARB l10n ES/EN + locale detection + language setting, every screen redone from `project/*.dc.html` (Reclamo is future: not implemented), async upload + pending states.

## Constraints
- Never persist statement PDFs (in-memory only while processing) nor full card numbers.
- Arithmetic stays deterministic in code; AI only extracts/classifies.
- Always confirm cashback % with the user (AWAITING_RATES step stays).
- No external payment mentions inside the iOS app.
- Fonts: Bodoni Moda (>= 22 px display) + Manrope; tabular figures for amounts; ISO currency codes.
- Status colors always paired with icon + text.
- TDD mode: off (source: project feature doc convention). Runners: `pnpm test` / `pnpm test:e2e` / `pnpm lint` (apps/api), `flutter analyze` + `flutter test` (apps/mobile).
- RDD: off (global). Delivery: ask-on-risk, branch `feat/mvp`, local work-unit commits only; push/PR are user decisions.

## Async verification contract (shared by backend and mobile)
- `POST /verifications` (multipart, same fields) → `202` with the verification summary, `status: "PROCESSING"`. Credit consumed on acceptance; refunded if it ends `FAILED`. Validation errors (file type/size, 402 NO_CREDITS) stay synchronous.
- Statuses: `PROCESSING` → `AWAITING_RATES` | `FAILED`; `AWAITING_RATES` → `COMPLETED` (via existing confirm).
- `FAILED` carries `failureCode`: `NOT_A_STATEMENT` | `EXTRACTION_FAILED` | `INTERRUPTED`.
- `GET /verifications/:id` works for every status (PROCESSING has no lines yet).
- `GET /verifications/attention` → `{ items: VerificationSummary[] }` with PROCESSING, AWAITING_RATES, and FAILED/COMPLETED not yet seen (`seenAt == null`).
- `POST /verifications/:id/seen` → 204, sets `seenAt`.
- On boot, PROCESSING rows left by a crash become `FAILED`/`INTERRUPTED` with credit refund (the PDF is gone).
- Mobile polls `GET /verifications/:id` (~4 s) while the screen is open and refreshes `attention` on Home load and app resume.

## Tasks
- [x] B1 Backend async lifecycle (statuses, background processor with bounded concurrency, refund on failure, boot recovery, attention + seen endpoints, tests, contract doc). Route: delegated (writer trigger: 2+ non-trivial files).
- [x] B2 Backend user preferences (locale, primaryCurrency, currencies with last rate) + credit history endpoint if missing. Route: delegated (same writer as B1).
- [x] M1 Mobile foundation: tokens → ColorScheme light/dark + status/creditCard ThemeExtension, atomic components (credit card, verdict card, movement row, rate field with source label, segmented filter, collapsible warning, bottom sheet, nav bar, buttons/chips/pills), ARB ES/EN with gen-l10n, locale detection (`en-*` → English, else Spanish) + Automatic/Español/English preference. Route: delegated.
- [x] M2 Splash + dynamic onboarding (bank → card → categories/% → login → first PDF → first verdict) + login + Home (empty / just onboarded / continuous use, pending verification banner). Route: delegated.
- [x] M3 Card form (basic/advanced) + Categories and merchants (guided empty / populated). Route: delegated.
- [x] M4 Verify (pick file, async processing, can leave) + Confirm percentages + Result (under/over/match, movements filter, change-category sheet with "remember"). Route: delegated.
- [x] M5 History (online/offline) + Paywall (free check / no credits) + Profile/Settings (profile, credit history, language and currencies) + M3 navigation bar (Inicio · Historial · Rubros · Perfil). Route: delegated.
- [ ] M6 Final pass: analyze, tests, run on device/simulator screenshots light/dark ES/EN.

## Acceptance criteria
- Screens match `project/*.dc.html` (layout, tokens, copy) in light and dark, ES and EN.
- Uploading a PDF returns immediately; closing the app does not lose the verification; reopening shows it pending / ready to review.
- All checks green: api `pnpm lint && pnpm test && pnpm test:e2e`, mobile `flutter analyze && flutter test`.

## Progress / evidence
- M1 done (commits 6b5cd10 l10n+locale; theme+components commit follows on feat/mvp). Checks in apps/mobile: `flutter gen-l10n` ok, `dart format --set-exit-if-changed lib test` 0 changed, `flutter analyze` no issues, `flutter test` 321 passed. Route: delegated writer. New: `lib/core/theme/app_colors.dart` (AppStatusColors), `lib/core/ui/` (atoms/molecules/organisms + `ui.dart` barrel), `lib/l10n/*.arb` (~400 keys), `LocaleController`.
- M2 done (commits 5f5bfbe async data layer, fbc0a04 onboarding+splash+login, home+shell commit follows on feat/mvp). Route: delegated writer. Checks in apps/mobile: `flutter gen-l10n` ok, `dart format --set-exit-if-changed lib test` 0 changed, `flutter analyze` no issues, `flutter test` 393 passed. New: `VerificationRepository.upload/get/attention/markSeen`, `VerificationPoller`, `AttentionController`, `Routes.verificationProgress`, guided setup (`features/onboarding`: draft in shared_preferences, `OnboardingSync` after sign-in), `AppNavigationShell` + `ShellController` (Routes.home), new Home states + `PendingBanner`. Pending for later tasks: card deletion moved out of Home (long-press gone; M3 card form), History tile/screen restyle (M5) already shows processing/failed labels, Upload/Verify screen (M4) now hands off to the progress page.
- M3 done (commits 1dfd5b2 card form; categories/merchants commit follows on feat/mvp). Route: delegated writer. Checks in apps/mobile: `flutter gen-l10n` ok, `dart format --set-exit-if-changed lib test` 0 changed, `flutter analyze` no issues, `flutter test` 421 passed. New: `AppField` (core/ui), `CardPreviewBand`, `CurrencyPicker`/`CurrencyChips`, advanced section + in-form delete (`CardFormController.delete`), `AppUser.primaryCurrency/currencies`, guided `CatalogView`, `CategoryReassignDialog`; `MerchantFormSheet` gained optional `onDelete` (API otherwise compatible). Open: design says deleting a card keeps its history, but the API cascades verifications on card delete, so the form says it deletes the history too (backend decision pending).
- M4 done (commits ef6a652 verify flow, 459f951 confirm; result + change-category sheet commit follows on feat/mvp). Route: delegated writer. Checks in apps/mobile: `flutter gen-l10n` ok, `dart format --set-exit-if-changed lib test` 0 changed, `flutter analyze` no issues, `flutter test` 449 passed. New: `UploadView` (card radio list, PDF box, credit pill), `ProcessingPanel` shared by upload and `VerificationProgressPage` (+ `FailedAnalysis` per failureCode with refunded pill and retry, `VerificationProgressArgs`), `ExchangeRateCard`/`RateEntryCard` on core `RateField` (source labels, optional cap), `AppUser.currencyRates` feeding `ConfirmRatesController.savedRates`, result tabs (Summary / Categories / Transactions) with core `VerdictCard`, `FilterSegmented` (4 options + counters), `MovementRow`, `ChangeCategorySheet` ("Remember for future checks" creates/updates the merchant via `CatalogController`, the line is always PATCHed and recalculated), `ResultController.changeCategory`/mark-seen on open, `core/ui/InlineNotice`. Card-delete copy now says the history is kept (ES/EN). Removed: old verdict card, transaction tile/section, breakdown, applied-rates, loyalty table, currency subtotals, explanation, category picker, analyzing progress, foreign/reward conversion cards. Deviations: Categories tab content is not in the design (applied rates, per-currency subtotals, programs); sheet title uses the sheet title style (20 px) instead of Bodoni 24; history rows still on the legacy tile (M5).
- M5 done (commits be61621 history, 5660c4c paywall, bdc82b7 profile/credit history/language and currencies; cleanup commit follows on feat/mvp). Route: delegated writer. Checks in apps/mobile: `flutter gen-l10n` ok, `dart format --set-exit-if-changed lib test` 0 changed, `flutter analyze` no issues, `flutter test` 488 passed. New: `HistoryRow` + sectioned `HistoryView` (Pending / Completed, status pills, deleted-card marker from `VerificationSummary.card`, offline banner), `PaywallView` in both design states (free check / no credits), `SettingsView` (profile, balance by bucket, shortcuts, appearance, sign out), `CreditHistoryView` (localized reasons incl. refunds), `LanguageCurrenciesView` + `PreferencesController` (`PATCH /me/preferences`: language, primary currency, add/remove currency, edit/clear rate, INVALID_CURRENCIES message), `Routes.languageCurrencies`. Language sync rule: on sign-in/start the server `locale` wins only while this phone never stored a choice; otherwise the phone choice wins and is pushed to the account. Cleanup: removed `lib/shared/widgets` (EmptyState/StaggeredEntrance moved to `core/ui`, InlineMessage replaced by InlineNotice), legacy status/verdict color views, `Get.snackbar` (notices use the app `ScaffoldMessenger`), unused routes and ~290 unused `S` facade members (the facade stays only for context-less controllers, validators and the error mapper). Deviations: offline banner has no "saved at" date (the cache keeps no timestamp); paywall legal line adds that the plan renews automatically (store requirement) to the design copy; profile has no legal/licenses row (none existed before); preferences changes are not written to the offline user cache (reloaded from `/me`).

## Next step
M6 final pass (analyze, tests, device/simulator screenshots light/dark ES/EN).
