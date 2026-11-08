# Cashback Audit - mobile app (Flutter)

Flutter client for the Cashback Audit API (`apps/api`). Users sign in with
Google or Apple, register cards and reward rules, organise merchants into
categories ("rubros"), upload a statement PDF and see whether the bank paid the
cashback/points they were owed. User-facing copy is Spanish (Mexico); code,
identifiers and comments are English. All copy lives in
`lib/core/l10n/strings.dart`.

The API contract is `docs/api-contract.md` (source of truth).

## Stack

- Flutter 3.47 / Dart 3.12, Material 3, light and dark themes
- GetX: state management, routing and DI (controllers are created by bindings)
- `animate_do` for entrances, verdict reveal and Hero transitions
- Drift (SQLite) as an offline read cache for cards, categories, merchants and
  verification history (network-first with cache fallback)
- Dio with a Bearer + single-flight refresh interceptor
- `flutter_secure_storage` (tokens), `shared_preferences` (onboarding flag)
- `google_sign_in` 7.x, `sign_in_with_apple`, `purchases_flutter` (RevenueCat),
  `file_picker`, `decimal` (money is never a `double`)

## Architecture

Clean/hexagonal, feature-first:

```
lib/
  core/            config, errors, l10n, network, storage, db (Drift), theme, routing, di
  shared/widgets/  atoms / molecules (atomic design), reused across features
  features/<feature>/
    domain/        pure Dart entities + abstract repositories/ports
    data/          repository implementations, mappers, SDK adapters
    presentation/  controllers (GetX), pages (containers), widgets (pure presentational)
```

Features: `auth`, `onboarding`, `splash`, `home`, `cards`, `categories`
(categories + merchants), `verifications`, `credits`, `subscription`,
`settings`.

Container/presentational split: `*_page.dart` are containers that read
controllers; `widgets/*_view.dart` are stateless and take data + callbacks.

## Setup

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter test
```

Generated Drift code (`lib/core/db/app_database.g.dart`) is committed so
`flutter test` works out of the box. Regenerate it after editing
`lib/core/db/tables.dart` or `app_database.dart`:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Running against the local backend

```bash
# repo root
docker compose up -d                # Postgres on :5433
cd apps/api && pnpm install && pnpm start:dev   # API on :3000 (see apps/api/README.md)

# mobile
cd apps/mobile
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api/v1        # iOS simulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1         # Android emulator
```

- The Android emulator reaches the host at `10.0.2.2`, not `localhost`. On a
  physical device use your machine's LAN IP.
- Debug builds allow cleartext HTTP (Android debug manifest) and local
  networking (iOS `NSAllowsLocalNetworking`). Use HTTPS in production and
  remove that ATS entry for release.
- To try verifications without a store purchase set
  `CREDITS_GATE_ENABLED=false` on the API (every new user also gets one free
  verification).

## Dart defines

| Define | Purpose |
| --- | --- |
| `API_BASE_URL` | Backend base URL (default `http://localhost:3000/api/v1`) |
| `GOOGLE_SERVER_CLIENT_ID` | **Web** OAuth client id; must be listed in the backend `GOOGLE_CLIENT_IDS` (it is the ID-token audience) |
| `GOOGLE_IOS_CLIENT_ID` | iOS OAuth client id (optional if `GoogleService-Info.plist` is bundled) |
| `REVENUECAT_IOS_KEY` | RevenueCat public SDK key for iOS |
| `REVENUECAT_ANDROID_KEY` | RevenueCat public SDK key for Android |
| `CREDIT_PACKS` | Consumable credit packs, `productId:credits` pairs (default `credits_3:3,credits_10:10`). **Must equal the backend `CREDIT_PACKS`**: only these product ids grant credits there, and the paywall hides any other non-subscription product |

Example:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1 \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=1234-web.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=1234-ios.apps.googleusercontent.com \
  --dart-define=REVENUECAT_ANDROID_KEY=goog_xxx \
  --dart-define=CREDIT_PACKS=credits_3:3,credits_10:10
```

Without a RevenueCat key the paywall shows a development notice instead of
crashing, and purchases are disabled.

## Native setup (manual steps)

### Google Sign-In

1. In Google Cloud Console create OAuth clients: **Web** (its id goes into the
   backend `GOOGLE_CLIENT_IDS` and the `GOOGLE_SERVER_CLIENT_ID` define),
   **iOS** (bundle id `com.cashbackaudit.cashbackAudit`) and **Android**
   (package `com.cashbackaudit.cashback_audit` + SHA-1 of your debug/release
   keystore).
2. iOS: in `ios/Runner/Info.plist` replace
   `com.googleusercontent.apps.REPLACE_WITH_REVERSED_IOS_CLIENT_ID` with your
   reversed iOS client id.
3. Android: no file is needed with `google_sign_in` 7.x (Credential Manager);
   the Android client must match package name + SHA-1.

### Sign in with Apple (iOS only; the button is hidden elsewhere)

1. Apple Developer portal: enable *Sign In with Apple* on the App ID.
2. `ios/Runner/Runner.entitlements` already declares the capability and is wired
   into the Xcode project (`CODE_SIGN_ENTITLEMENTS`). Select your team under
   *Signing & Capabilities*.
3. Set the backend `APPLE_BUNDLE_ID` to the iOS bundle id
   (`com.cashbackaudit.cashbackAudit` unless you change it).

### RevenueCat

1. Create the project, add the iOS and Android apps and copy the **public SDK
   keys** into the dart-defines above.
2. Create an entitlement with the id the backend expects
   (`REVENUECAT_ENTITLEMENT_ID`, default `pro`), attach your monthly
   subscription product (US$4.99/month, 5 verifications per period, not
   cumulative) and put it in the **current offering**.
3. Create the **consumable** credit-pack products in App Store Connect / Google
   Play (e.g. `credits_3`, `credits_10`), add them to RevenueCat and to the
   **same current offering** as extra packages (type *custom*). Their product
   ids must match the `CREDIT_PACKS` dart-define **and** the backend
   `CREDIT_PACKS` setting. They do not need an entitlement: the backend grants
   the credits from the `NON_RENEWING_PURCHASE` webhook event.
4. Configure the webhook to `POST /api/v1/webhooks/revenuecat` with the
   `Authorization` value from `REVENUECAT_WEBHOOK_AUTH`.
5. The app calls `Purchases.logIn(user.id)` right after sign-in (and at app
   start when restoring the session) and `Purchases.logOut()` on sign-out, so
   webhook events map to our users.
6. iOS: add the *In-App Purchase* capability in Xcode. Android: the
   `com.android.vending.BILLING` permission is declared in the manifest.

## Behaviour notes

- **Auth**: access token is refreshed transparently on `401 INVALID_ACCESS_TOKEN`;
  concurrent requests share one refresh call (refresh tokens are single use).
  A rejected refresh (4xx) clears tokens and sends the user to login; being
  offline never logs the user out.
- **Offline**: cards, categories, merchants, history page 1 and opened
  verification details are served from the Drift cache when the network is
  unavailable (an "offline" banner is shown). The cache is wiped on logout.
- **Verification flow (two steps)**: 1) the user picks a card and the PDF; the
  upload costs one credit and shows an "analyzing" state (about a minute; steps
  *Leyendo estado de cuenta* then *Clasificando movimientos*, advanced by
  elapsed time because the backend is a single request). 2) The **rate
  confirmation** screen is built from `rateProposal`: one field per entry (the
  base rate plus each category). Values found in the statement carry a
  "Detectado en tu estado de cuenta" badge and the quoted `evidence`; values from
  the card show "De las reglas de tu tarjeta"; entries with no value are
  *Obligatorio* and the confirm button stays disabled until they are filled.
  Optional per-category monthly cap, a "Guardar estos % en la tarjeta" switch
  (`saveToCard`) and, only when the statement has foreign-currency purchases, an
  optional exchange rate (without one those lines are excluded). If the
  statement lists several loyalty programs a chooser appears (also on
  `REWARD_PROGRAM_AMBIGUOUS`); `REPORTED_REWARD_NOT_FOUND` asks for the reward
  figure. Then `POST /verifications/:id/confirm` and the result opens.
  Statements left unconfirmed appear in the history with a
  "Pendiente de confirmar %" chip and resume in the same screen (the server
  deletes them after 7 days).
- **Reward currency and any-currency rates**: money is always printed with its
  ISO 4217 code and the currency's minor units (`USD 22.68`, `JPY 1,500`,
  `KWD 1.250`); there are no per-country currency assumptions. When
  `rewardConversion` is present the confirmation screen asks (required) how many
  card-currency units one reward-currency unit is worth ("¿Cuántos HNL vale
  1 USD?", prefilled when the statement prints it) and sends
  `rewardExchangeRate`; each `exchangeRateProposal` entry gets an optional field
  sent in the `exchangeRates` map (empty = those purchases are left out). A card
  can set the reward currency explicitly (empty = detected). Statement
  categories the user lacks (`suggestedCategories`) can be created for free from
  the same screen (`POST .../categories-from-suggestions`), refreshing the
  proposal in place. The result shows reported/expected/difference in the reward
  currency with an "Equivale a HNL 589.61" line, the applied conversion rate,
  credit lines labelled by `creditType` (payment / refund / other credit) and a
  "Tu banco lo considera: ..." hint on uncategorized lines.
- **Uploads**: PDF only, max 10 MB (checked client side), multipart with upload
  progress (receive timeout 3 min). No automatic retry on timeout (the request
  consumes a credit); the UI tells the user to check history first.
- **Result screen**: verdict, a Spanish `explanation` card, reported vs expected,
  the loyalty program table (all columns, the audited row highlighted, a
  "Posible saldo acumulado" chip when the reported figure may be a running
  balance), per-currency subtotals, localized warnings, the rates used and
  **Recalcular con otros %** (reopens the confirmation prefilled with
  `appliedRates`). Statement lines come in three styles: green (counted in a
  category; "IA" chip for AI matches with `matchReason` as subtitle), red (a
  purchase outside every category) and grey (excluded: payments, fees, interest,
  insurance, foreign lines without a rate, with the reason in Spanish). Filter:
  Todos / En rubro / Sin rubro / Excluidos with counts. Tapping a line changes
  its category (`PATCH .../transactions/:index`) and the result is recalculated
  right away with the same rates (`POST confirm`, free, no credit).
- **Credits and paywall**: the backend is the source of truth for the balance
  (`GET /credits/me`), shown as a chip on Home ("N verificaciones disponibles"),
  before the upload and in Settings, with the ledger at *Historial de
  verificaciones*. `402 NO_CREDITS` opens the paywall: the monthly subscription
  (5 verifications per month, not cumulative) and the consumable packs of the
  current RevenueCat offering (identified by product id through `CREDIT_PACKS`),
  with first-verification-free messaging for users who still have the free
  credit. After a purchase the app polls `GET /credits/me` with backoff (~25 s)
  until the balance changes, because the RevenueCat webhook is asynchronous.
  Restore purchases stays available. Payments only go through the store (no
  external or web payment is mentioned, App Store guideline 3.1.1).
- **Cache**: Drift `schemaVersion` 2 drops verification payloads cached with the
  previous contract on upgrade; mappers also tolerate old rows (no `status`,
  `currency`, `kind`, `creditType`, `rewardCurrency`, legacy `AI` match source,
  single `statementRate`). The reward-currency fields are optional on read, so
  no schema bump was needed.

## Tests

```bash
flutter test
```

Covers the Dio refresh interceptor (single flight, logout on rejected refresh),
error mapping, decimal handling, repositories against a fake Dio adapter,
controllers (auth, cards, catalog, upload, rate confirmation, result and line
correction, history, credits polling, paywall) and key presentational widgets
(rate entries, transaction tiles and filter, loyalty table, paywall, credits
chip).

## Building

```bash
flutter build apk --debug
```

Release builds need your own signing configuration.
