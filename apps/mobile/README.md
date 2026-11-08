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
(categories + merchants), `verifications`, `subscription`, `settings`.

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
  `SUBSCRIPTION_GATE_ENABLED=false` on the API.

## Dart defines

| Define | Purpose |
| --- | --- |
| `API_BASE_URL` | Backend base URL (default `http://localhost:3000/api/v1`) |
| `GOOGLE_SERVER_CLIENT_ID` | **Web** OAuth client id; must be listed in the backend `GOOGLE_CLIENT_IDS` (it is the ID-token audience) |
| `GOOGLE_IOS_CLIENT_ID` | iOS OAuth client id (optional if `GoogleService-Info.plist` is bundled) |
| `REVENUECAT_IOS_KEY` | RevenueCat public SDK key for iOS |
| `REVENUECAT_ANDROID_KEY` | RevenueCat public SDK key for Android |

Example:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1 \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=1234-web.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=1234-ios.apps.googleusercontent.com \
  --dart-define=REVENUECAT_ANDROID_KEY=goog_xxx
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
   (`REVENUECAT_ENTITLEMENT_ID`, default `pro`), attach your monthly product and
   put it in the **current offering**.
3. Configure the webhook to `POST /api/v1/webhooks/revenuecat` with the
   `Authorization` value from `REVENUECAT_WEBHOOK_AUTH`.
4. The app calls `Purchases.logIn(user.id)` right after sign-in (and at app
   start when restoring the session) and `Purchases.logOut()` on sign-out, so
   webhook events map to our users.
5. iOS: add the *In-App Purchase* capability in Xcode. Android: the
   `com.android.vending.BILLING` permission is declared in the manifest.

## Behaviour notes

- **Auth**: access token is refreshed transparently on `401 INVALID_ACCESS_TOKEN`;
  concurrent requests share one refresh call (refresh tokens are single use).
  A rejected refresh (4xx) clears tokens and sends the user to login; being
  offline never logs the user out.
- **Offline**: cards, categories, merchants, history page 1 and opened
  verification details are served from the Drift cache when the network is
  unavailable (an "offline" banner is shown). The cache is wiped on logout.
- **Uploads**: PDF only, max 10 MB (checked client side), multipart with upload
  progress, then an indeterminate "analyzing" phase (receive timeout 3 min). No
  automatic retry on timeout (the request consumes quota); the UI tells the user
  to check history first.
- **Result screen**: every transaction is marked counted (green check, "Contó en
  rubro", category + applied rate, "IA" chip for AI matches) or not counted (red
  cross, "Sin rubro", base rate only), with an All / En rubro / Sin rubro filter.
  Uncounted lines have an "Asignar a rubro" action that creates a merchant
  (`POST /merchants`) with the statement descriptor as keyword; it applies to
  **future** verifications.
- **Paywall**: `402 SUBSCRIPTION_REQUIRED` opens the paywall. After a purchase or
  restore the app polls `GET /subscriptions/me` with backoff (~25 s) until the
  backend reports `active`, because the RevenueCat webhook is asynchronous.

## Tests

```bash
flutter test
```

Covers the Dio refresh interceptor (single flight, logout on rejected refresh),
error mapping, decimal handling, repositories against a fake Dio adapter,
controllers (auth, cards, catalog, upload, result, history, subscription,
paywall) and key presentational widgets.

## Building

```bash
flutter build apk --debug
```

Release builds need your own signing configuration.
