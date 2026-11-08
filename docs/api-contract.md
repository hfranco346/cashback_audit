# Cashback Audit API contract (v1)

This is the contract the Flutter app builds against. The OpenAPI document is
also served by the running API at `GET /docs` (Swagger UI), but this file is the
source of truth for behaviour, error codes and conventions.

- Base URL (dev): `http://localhost:3000/api/v1`
- All request and response bodies are JSON (`Content-Type: application/json`),
  except `POST /verifications` which is `multipart/form-data`.
- Every route requires `Authorization: Bearer <accessToken>` unless marked
  **Public**.

## Contents

1. [Conventions](#1-conventions)
2. [Authentication flow](#2-authentication-flow)
3. [Auth endpoints](#3-auth-endpoints)
4. [Current user](#4-current-user)
5. [Categories](#5-categories)
6. [Merchants](#6-merchants)
7. [Cards](#7-cards)
8. [Verifications](#8-verifications)
9. [Subscriptions and the paywall](#9-subscriptions-and-the-paywall)
10. [Health](#10-health)
11. [Error reference](#11-error-reference)
12. [Changelog (breaking changes)](#12-changelog-breaking-changes)

---

## 1. Conventions

### Errors

Every error, from any endpoint, has the same shape:

```json
{
  "statusCode": 404,
  "code": "CARD_NOT_FOUND",
  "message": "Card not found"
}
```

`details` is only present when there is extra structured information (see
[Error reference](#11-error-reference)). Branch on `code`, not on `message`
(`message` is English text meant for logs, not for display).

Validation failures are `400` with `code: "VALIDATION_ERROR"`,
`message: "Validation failed"` and `details` set to an array of strings, one
per violated rule:

```json
{
  "statusCode": 400,
  "code": "VALIDATION_ERROR",
  "message": "Validation failed",
  "details": ["last4 must be exactly 4 digits"]
}
```

Unknown properties in a request body are rejected with `400` (the API uses
`forbidNonWhitelisted`), so only send documented fields.

### Decimal numbers (money, rates, rewards)

All money, rate and reward values in **responses are JSON strings** holding an
exact decimal, e.g. `"1.5"`, `"125.40"`, `"0"`. Do not parse them as `double`
for arithmetic: use a decimal type (or keep them as strings and format for
display). The scale is not fixed: trailing zeros are removed (`"58"`, not
`"58.00"`; `"500.5"`, not `"500.50"`). Format with your own locale rules for
display.

In **requests**, decimal fields accept either a JSON string (`"5"`, `"1.25"`) or
a JSON number (`5`, `1.25`); the server normalizes both to exact decimals.
Strings are preferred. Exponent notation (`1e3`) and negative values are
rejected where not meaningful.

Rates are expressed in **percent** (`"5"` means 5 %).

### Dates and times

- Timestamps (`createdAt`, `updatedAt`, `expiresAt`): ISO 8601 UTC with
  milliseconds, e.g. `"2026-01-31T18:04:05.123Z"`.
- Statement dates (`periodStart`, `periodEnd`, transaction `date`):
  calendar dates `"YYYY-MM-DD"` with no timezone.

### IDs

All ids are UUID strings. A malformed id in a path or query is a `400`.

### Ownership

Cards, categories, merchants and verifications belong to the authenticated user.
Requesting a resource that exists but belongs to someone else returns `404`
(never `403`), exactly like a resource that does not exist.

### Lists and pagination

`GET /cards`, `GET /categories` and `GET /merchants` return a plain JSON array
(not paginated; users have a handful of each). `GET /verifications` is
paginated (see section 8).

### Rate limiting

- Default: 120 requests per minute per user (per IP when unauthenticated).
- `POST /verifications`: 5 requests per minute per user.

Exceeding a limit returns `429` with `code: "TOO_MANY_REQUESTS"`. The `Retry-After`
header says how many seconds to wait.

### Character data

Free-text fields are trimmed by the server where noted. Maximum lengths are in
each section; exceeding them is a `400`.

---

## 2. Authentication flow

The app never sees a password. It gets an identity token from Google or Apple
on the device, exchanges it once for our own tokens, and then only uses our
tokens.

```
Flutter app                       Google / Apple              Our API
    |  native sign-in                    |                       |
    |----------------------------------->|                       |
    |<-- idToken / identityToken --------|                       |
    |  POST /auth/google  {idToken}  (or /auth/apple)            |
    |----------------------------------------------------------->|  verifies the token
    |<-- {accessToken, refreshToken, expiresIn, user} -----------|  upserts the user
    |  GET /cards  Authorization: Bearer <accessToken>           |
    |----------------------------------------------------------->|
    |  401 INVALID_ACCESS_TOKEN (token expired)                  |
    |<-----------------------------------------------------------|
    |  POST /auth/refresh {refreshToken}                         |
    |----------------------------------------------------------->|  rotates the pair
    |<-- {accessToken, refreshToken, expiresIn} -----------------|
    |  retry the original request with the new access token      |
```

Rules the client must follow:

1. **Access token**: short-lived JWT (`expiresIn` seconds, default 900 = 15 min).
   Send as `Authorization: Bearer <accessToken>`. When any request returns
   `401` with `code: "INVALID_ACCESS_TOKEN"`, refresh and retry once.
2. **Refresh token**: long-lived (default 30 days) and **single use**. Every
   successful `POST /auth/refresh` returns a *new* refresh token and revokes the
   old one. Always persist the newest pair (use secure storage) before using it.
3. **Reuse detection**: presenting an already-used refresh token is treated as
   theft; the whole session (every token descended from that sign-in) is
   revoked and the call returns `401 INVALID_REFRESH_TOKEN`. If that happens,
   or the refresh call fails with 401 for any reason, send the user back to
   sign-in. Serialize refresh calls in the app (one in flight at a time) so two
   concurrent requests do not race and trigger reuse detection.
4. **Logout**: `POST /auth/logout` with the refresh token, then delete both
   tokens locally.
5. **Google**: use the Google Sign-In SDK to obtain an **ID token** (not the
   access token) for the OAuth client ID registered in the backend
   (`GOOGLE_CLIENT_IDS`).
6. **Apple**: use Sign in with Apple to obtain the `identityToken`. Apple only
   returns the user's name (`givenName`, `familyName`) on the **first**
   authorization for the app; send it as `fullName` (`"Given Family"`) in that
   call. The backend stores it on first sight and never erases it afterwards.
   Later sign-ins can omit `fullName`.
7. The user is identified by `(provider, providerSubject)`. Signing in with
   Google and with Apple creates **two separate accounts** (no account linking
   in v1).

---

## 3. Auth endpoints

All **Public**.

### POST /auth/google

Request:

```json
{ "idToken": "<Google ID token>" }
```

`200` response:

```json
{
  "accessToken": "eyJhbGciOi...",
  "refreshToken": "eyJhbGciOi...",
  "tokenType": "Bearer",
  "expiresIn": 900,
  "user": {
    "id": "0b0e7d0e-5a43-4b6c-8a3f-3d9a0c5c1e11",
    "email": "ana@example.com",
    "name": "Ana Perez"
  }
}
```

`email` and `name` may be `null`. The `user.id` is the RevenueCat app user id
(see section 9).

Errors: `400` validation, `401 INVALID_IDENTITY_TOKEN` (forged, expired or wrong
audience), `503 IDENTITY_PROVIDER_UNAVAILABLE` (Google client IDs not
configured on the server).

### POST /auth/apple

Request:

```json
{ "identityToken": "<Apple identity token (JWT)>", "fullName": "Beto Gomez" }
```

`fullName` is optional (max 200 chars). Response and errors are identical to
`/auth/google`; for a returning user whose name is already stored, `user.name`
keeps the stored value.

### POST /auth/refresh

Request:

```json
{ "refreshToken": "eyJhbGciOi..." }
```

`200` response (no `user`):

```json
{
  "accessToken": "eyJhbGciOi...",
  "refreshToken": "eyJhbGciOi...",
  "tokenType": "Bearer",
  "expiresIn": 900
}
```

Errors: `401 INVALID_REFRESH_TOKEN` (unknown, expired, revoked or reused).

### POST /auth/logout

Request: `{ "refreshToken": "..." }`. Response: `204` with no body. Idempotent:
unknown or already revoked tokens also return `204`. Revokes the whole session.

---

## 4. Current user

### GET /me

`200`:

```json
{
  "id": "0b0e7d0e-5a43-4b6c-8a3f-3d9a0c5c1e11",
  "provider": "GOOGLE",
  "email": "ana@example.com",
  "name": "Ana Perez",
  "createdAt": "2026-01-01T00:00:00.000Z"
}
```

`provider` is `"GOOGLE"` or `"APPLE"`. Errors: `401`.

---

## 5. Categories

A category ("rubro") groups merchants, e.g. `Supermarkets`. Card reward rules are
defined per category. Names are unique per user (case-sensitive).

Category object:

```json
{
  "id": "6f1c...",
  "name": "Supermarkets",
  "description": null,
  "merchantCount": 2,
  "createdAt": "2026-01-01T00:00:00.000Z",
  "updatedAt": "2026-01-01T00:00:00.000Z"
}
```

### POST /categories

Request: `{ "name": "Supermarkets", "description": "Groceries" }` -
`name` required (1-80 chars, trimmed), `description` optional/nullable
(max 500). `201` returns the category object with `merchantCount: 0`.
Errors: `409 CATEGORY_NAME_TAKEN`.

### GET /categories

Optional query `includeMerchants=true` embeds each category's merchants:

```json
[
  {
    "id": "6f1c...",
    "name": "Supermarkets",
    "description": null,
    "merchantCount": 2,
    "merchants": [
      {
        "id": "a2b9...",
        "name": "Soriana",
        "keywords": [],
        "categoryId": "6f1c...",
        "createdAt": "2026-01-01T00:00:00.000Z",
        "updatedAt": "2026-01-01T00:00:00.000Z"
      }
    ],
    "createdAt": "2026-01-01T00:00:00.000Z",
    "updatedAt": "2026-01-01T00:00:00.000Z"
  }
]
```

Sorted by name. Without `includeMerchants`, the `merchants` key is absent.

### GET /categories/:id

Category object plus `merchants` (always included). `404 CATEGORY_NOT_FOUND`.

### PATCH /categories/:id

Request: any of `name`, `description`. `200` returns the category object
**without** `merchantCount` (re-fetch if you need it). Errors:
`404 CATEGORY_NOT_FOUND`, `409 CATEGORY_NAME_TAKEN`.

### DELETE /categories/:id

`204` on success.

- If the category still has merchants **or** is used by card rules and no
  `reassignTo` is given: `409 CATEGORY_IN_USE` with
  `details: { "merchants": 2, "cardRules": 1 }`.
- `DELETE /categories/:id?reassignTo=<categoryId>`: moves the merchants to the
  target category and moves the card rules to it too (if a card already has a
  rule for the target, the deleted category's rule for that card is dropped),
  then deletes. The target must be one of your categories and different from
  the one being deleted, otherwise `404 CATEGORY_NOT_FOUND`.

---

## 6. Merchants

A merchant is a shop the user cares about, with the **category it is expected to
accrue under**. `keywords` are aliases / statement descriptors used to match
statement lines (for example `"WAL MART"`, `"WALMART SUC"`). Names are unique
per user.

Merchant object:

```json
{
  "id": "a2b9...",
  "name": "Walmart",
  "keywords": ["WAL MART", "WALMART SUC"],
  "categoryId": "6f1c...",
  "createdAt": "2026-01-01T00:00:00.000Z",
  "updatedAt": "2026-01-01T00:00:00.000Z"
}
```

### POST /merchants

Request:

```json
{ "name": "Walmart", "keywords": ["WAL MART", "WALMART SUC"], "categoryId": "6f1c..." }
```

`name` required (1-120), `categoryId` required (must be yours, else
`404 CATEGORY_NOT_FOUND`), `keywords` optional (max 30 entries of max 120 chars;
the server trims, drops empties and removes case-insensitive duplicates).
`201` returns the merchant. Errors: `409 MERCHANT_NAME_TAKEN`.

Matching hints for users: keywords and the name are compared after lowercasing,
removing accents and punctuation, and also ignoring spaces, so `WAL MART`
matches `WALMART SUC 123`. Terms shorter than 3 characters are ignored.

### GET /merchants

Optional query `categoryId=<uuid>`. Returns an array sorted by name.

### GET /merchants/:id

`404 MERCHANT_NOT_FOUND`.

### PATCH /merchants/:id

Any of `name`, `keywords` (replaces the whole list), `categoryId` (reassigns the
merchant to another of your categories; `404 CATEGORY_NOT_FOUND` otherwise).
Returns the merchant. Errors: `404 MERCHANT_NOT_FOUND`, `409 MERCHANT_NAME_TAKEN`.

### DELETE /merchants/:id

`204`. `404 MERCHANT_NOT_FOUND`.

---

## 7. Cards

The API never accepts or stores a full card number: only the last four digits.

Card object:

```json
{
  "id": "c3d4...",
  "alias": "Daily card",
  "bank": "BBVA",
  "last4": "4321",
  "network": "VISA",
  "rewardUnit": "CASHBACK_CURRENCY",
  "pointsPerCurrencyUnit": "1",
  "baseRatePercent": "1.5",
  "currency": "MXN",
  "rewardProgramName": null,
  "rewardCurrency": null,
  "rules": [
    { "categoryId": "6f1c...", "ratePercent": "5", "monthlyCap": "500" }
  ],
  "createdAt": "2026-01-01T00:00:00.000Z",
  "updatedAt": "2026-01-01T00:00:00.000Z"
}
```

Field rules:

| Field | Type | Rules |
| --- | --- | --- |
| `alias` | string | required, 1-60 chars, trimmed |
| `bank` | string | required, 1-60 chars, trimmed |
| `last4` | string | required, **exactly 4 digits** (`^\d{4}$`). 5+ digits, a full PAN, or non-digits is `400` |
| `network` | string or null | optional, max 30 (`"VISA"`, `"MASTERCARD"`, ...) |
| `rewardUnit` | enum | required: `CASHBACK_CURRENCY` (reward is money in the card currency) or `POINTS` |
| `pointsPerCurrencyUnit` | decimal | optional, default `"1"`, `> 0` and `<= 1000`, max 4 decimals. Only used for `POINTS`: points earned per 1 unit of reward value |
| `baseRatePercent` | decimal | required, `0-100`, max 4 decimals. Rate for any spend with no matching rule |
| `currency` | string | required, ISO 4217 code (`HNL`, `USD`...). Uppercased by the server. The card's **primary currency**: rates, caps, rewards and totals are expressed in it. Statement lines in other currencies are converted into it (see section 8) |
| `rewardProgramName` | string or null | optional, max 80 chars, trimmed, `null`/`""` clears it. Name of the loyalty program to audit when the statement lists several (e.g. `"CASH BAC CREDOMATIC"`). Matched case/accent-insensitively with "contains" against the program names printed on the statement |
| `rewardCurrency` | string or null | optional ISO 4217 code, `null`/`""` clears it. Currency the **reward is paid in** when it differs from `currency` (spend in `HNL`, cashback in `USD`). Overrides what the statement indicates. Effective reward currency = `rewardCurrency` ?? the chosen program's `currency` ?? `currency`. Ignored for `POINTS` cards (no conversion applies) |
| `rules` | array | optional, max 50, **one rule per category** |

Rule (`rules[]`):

| Field | Type | Rules |
| --- | --- | --- |
| `categoryId` | uuid | required, must be one of your categories (`404 CATEGORY_NOT_FOUND`); duplicates are `400 DUPLICATE_RULE_CATEGORY` |
| `ratePercent` | decimal | required, `0-100`, max 4 decimals |
| `monthlyCap` | decimal or null | optional, `> 0`, max 2 decimals. Maximum reward obtainable from this rule per statement period, **in the card's reward unit** (currency for cashback cards, points for `POINTS` cards). `null`/absent = no cap |

How the expected reward is computed (so the UI can explain it). The card's
rates are only the **default proposal**: every verification is audited with the
rates the user confirms (section 8). For each
transaction the rate is the card rule of the transaction's category if the
card has one, otherwise `baseRatePercent`. Refunds/credits subtract. Lines in a
foreign currency are first converted into the card currency. For
`POINTS` cards the reward is multiplied by `pointsPerCurrencyUnit`. Each rule's
total for the statement is then limited to its `monthlyCap`. When the reward
is paid in another currency than the card's, the total (computed in the card
currency) is finally converted with the reward exchange rate. Money amounts are
rounded **once, at the end**, to the ISO 4217 minor units of their currency
(0 decimals for `JPY`/`CLP`/..., 3 for `KWD`/..., 2 for the rest), half up.

### POST /cards

Request body = the fields above (without `id`/timestamps). `201` returns the
card. Errors: `400`, `404 CATEGORY_NOT_FOUND`.

```json
{
  "alias": "Daily card",
  "bank": "BBVA",
  "last4": "4321",
  "rewardUnit": "CASHBACK_CURRENCY",
  "baseRatePercent": "1",
  "currency": "MXN",
  "rules": [{ "categoryId": "6f1c...", "ratePercent": "5", "monthlyCap": "500" }]
}
```

### GET /cards

Array sorted by creation date (oldest first).

### GET /cards/:id

`404 CARD_NOT_FOUND`.

### PATCH /cards/:id

Any subset of the create fields. If `rules` is present it **replaces all rules**
(send `[]` to remove them all); if absent, rules are untouched. `200` returns the
card. Errors: `400`, `404 CARD_NOT_FOUND`, `404 CATEGORY_NOT_FOUND`.

### DELETE /cards/:id

`204`. **Also deletes the verification history of that card.**

---

## 8. Verifications

A verification audits one statement in **two steps**:

1. **Upload** (`POST /verifications`): the backend has Claude read the PDF,
   classifies the lines into your categories and stores the result as
   `AWAITING_RATES`. It also proposes the reward rates to audit (from the
   statement, from the card, or nothing). **No reward is computed yet.**
2. **Confirm** (`POST /verifications/:id/confirm`): the user confirms or edits
   the rates; the backend computes the reward the card *should* have earned
   deterministically and compares it with the reward the bank reported. The same
   call recalculates a `COMPLETED` verification with other rates (no new Claude
   call, no cost).

Banks change their cashback policies often, so the app should **always** show
the proposed rates to the user and let them confirm or edit before step 2.

**The PDF is processed in memory and discarded; only extracted results are
stored.**

`status`: `AWAITING_RATES` (after step 1) or `COMPLETED` (after step 2).
While `AWAITING_RATES` the fields `reported`, `expected`, `difference`,
`tolerance`, `verdict`, `appliedRates` are `null`, `breakdown` and `currencies`
are `[]`, and per-transaction `expectedReward`, `appliedRatePercent` and
`convertedAmount` are `null`.

### POST /verifications  (step 1)

`Content-Type: multipart/form-data` with these parts:

| Part | Required | Notes |
| --- | --- | --- |
| `file` | yes | The statement PDF. `application/pdf` only, max **10 MB** (10 485 760 bytes). The content must really be a PDF |
| `cardId` | yes | UUID of one of your cards |
| `exchangeRate` | no | Decimal string `> 0`, max 6 decimals, e.g. `"26.35"`: how many units of the **card currency** one unit of the foreign currency is worth (foreign -> primary). Wins over a rate printed on the statement. Applied to every foreign currency on the statement. Stored with the verification (it can be replaced at confirm time) |
| `rewardProgramName` | no | 1-80 chars. Loyalty program to audit (same matching as the card field); overrides the card's `rewardProgramName`. An empty value is ignored. Stored with the verification (it can be replaced at confirm time) |

`reportedRewardOverride` is **no longer accepted here** (it is part of step 2).

Dart/Dio sketch:

```dart
final form = FormData.fromMap({
  'cardId': cardId,
  'file': await MultipartFile.fromFile(path, filename: 'statement.pdf',
      contentType: MediaType('application', 'pdf')),
});
await dio.post('/verifications', data: form,
    options: Options(receiveTimeout: const Duration(minutes: 3)));
```

**Latency**: analysis typically takes 10-60 seconds and can take longer for large
statements. Use a receive timeout of at least 3 minutes and show a progress UI.
The request is not idempotent: do not auto-retry on timeout without asking
the user (each call consumes quota); check `GET /verifications` first.

**Order of checks** (first failure wins): auth (`401`) -> rate limit (`429`) ->
credits (`402 NO_CREDITS`, step 1 only: this is where the analysis cost is) -> upload
type/size (`415`/`413`) -> field validation (`400`) -> PDF signature
(`400 INVALID_PDF`) -> card ownership (`404`) -> credit reservation (`402`, atomic)
-> analysis (`422`/`502`/`503`, credit refunded).

**Multi-currency.** Statements can have one amount column per currency (e.g.
Lempiras and Dolares). Every transaction carries its own `currency` (ISO 4217).
Lines in the card's primary currency are used as is. Foreign lines are converted
into it with, in this order: (1) the request `exchangeRate`, (2) the rate printed
on the statement (`conversion.statementRate`; a rate printed in the opposite
direction is inverted), (3) none. With no rate the request still **succeeds**:
the expected reward is computed on the primary-currency lines only, the foreign
lines come back with `excludedReason: "NO_EXCHANGE_RATE"` and the warning
`NO_EXCHANGE_RATE` is added; the client can offer the user to confirm again with
`exchangeRate`. Conversion happens in step 2.

**Line kinds.** Every extracted line has a `kind`: `PURCHASE`, `REFUND`, `FEE`,
`INTEREST`, `INSURANCE`, `PAYMENT`, `OTHER`. Only `PURCHASE` and `REFUND` earn
rewards; other kinds are returned with `excludedReason: "NON_PURCHASE_KIND"`, are
never matched to a merchant/category and add 0.

**Loyalty programs.** The statement may list several programs (e.g. "PUNTOS BAC
CREDOMATIC" and "CASH BAC CREDOMATIC"). The audited program is chosen as: the
request `rewardProgramName`, else the card's `rewardProgramName` (both:
case/accent-insensitive "contains"; an exact name wins over a partial match),
else the only program if there is exactly one. If it cannot be determined (several
programs and no/unmatched name) the response is `422 REWARD_PROGRAM_AMBIGUOUS`
with `details.programs` (array of names): let the user pick and retry with
`rewardProgramName`. **Step 1 never fails because of this**: it stores every
program and, when it cannot choose, returns `loyalty.selectedProgram: null`;
the `422` is raised by step 2 unless it carries `rewardProgramName` or
`reportedRewardOverride`.
The value audited is the program's **`accumulated`** ("Acumulados") column unless
overridden; the other columns are exposed in `loyalty.programs`.

How lines are matched to your categories (only `PURCHASE`/`REFUND` lines take
part; categories do **not** need registered merchants):

1. **Keyword match** (`matchSource: "KEYWORD"`): the statement line is compared
   to every merchant's name and keywords (case/accent/punctuation/space
   insensitive, "contains"); the longest matching term wins. The line gets the
   merchant's category.
2. **AI classification** (one batched Claude call per up to 100 distinct
   unmatched lines, cheap model): the model receives all your categories (name,
   optional `description`, and your registered merchants as examples) and answers
   per line a category, optionally a registered merchant, a 0-1 `confidence` and a
   short `reason`. Results with confidence below the server threshold (default
   0.7) are discarded.
   - `matchSource: "AI_MERCHANT"`: the model matched one of your registered
     merchants (`matchedMerchantId` set; category = that merchant's category).
   - `matchSource: "AI_CATEGORY"`: the model chose a category only
     (`matchedMerchantId: null`). This is what makes "everything that is a
     supermarket/pharmacy counts" work without registering every merchant: give
     the category a descriptive `description`.
   `matchConfidence` is the 0-1 confidence and `matchReason` the short
   explanation (both `null` for keyword/none).
   A line the user re-categorized through `PATCH .../transactions/:index` has
   `matchSource: "USER"`.
3. **No match** (`matchSource: "NONE"`): the line earns the card's base rate.

Lines that are not purchases (`kind` other than `PURCHASE`/`REFUND`) are never
classified. If classification fails (fully or for some lines) the verification
still succeeds using keyword matches and carries the warning
`AI_MATCHING_UNAVAILABLE`.

**Rate proposal.** The extraction also reads the reward rates the statement
itself states (`detectedRates[]`: `{ scope: "BASE"|"CATEGORY", categoryHint,
suggestedCategoryId, ratePercent, unitNote, evidence, confidence }`;
`ratePercent` is a percent of spend or `null` when it cannot be expressed that
way, with the original wording in `unitNote`; `evidence` is a short quote).
`rateProposal[]` merges that with the card rules:

- one entry for the base (`categoryId: null`), and one for every category that
  has at least one classified purchase/refund line **or** a card rule;
- `source`: `STATEMENT` (the document states it; detections below 0.5 confidence
  or without a percentage are ignored) > `CARD_RULE` (the card has it; the base
  falls back to the card's `baseRatePercent`) > `NONE`;
- `required: true` exactly when `source` is `NONE`: the client must make the user
  type a rate (`ratePercent` is `null`), otherwise step 2 answers
  `422 RATES_REQUIRED`;
- `monthlyCap`: the card rule's cap, if any (the statement never states one);
- `evidence` / `unitNote`: for `STATEMENT` entries.

`GET /verifications/:id` always recomputes the proposal against the current card
rules and classification, so it also prefills a recalculation.

`201` response (full verification object, here after step 1):

```json
{
  "id": "e5f6...",
  "cardId": "c3d4...",
  "status": "AWAITING_RATES",
  "statement": { "bank": "Example Bank", "cardLast4": "4321", "periodStart": "2026-01-01", "periodEnd": "2026-01-31", "currency": "MXN", "totalSpent": "1400", "totalToPay": "1400", "summaries": [ { "currency": "MXN", "previousBalance": "0", "purchasesAndCharges": "1400", "totalBalance": "1400" } ] },
  "primaryCurrency": "MXN",
  "reported": null,
  "expected": null,
  "difference": null,
  "tolerance": null,
  "verdict": null,
  "explanation": null,
  "detectedRates": [
    { "scope": "BASE", "categoryHint": null, "suggestedCategoryId": null, "ratePercent": "1", "unitNote": null, "evidence": "1% cashback on all purchases", "confidence": 0.9 },
    { "scope": "CATEGORY", "categoryHint": "supermarkets", "suggestedCategoryId": "6f1c...", "ratePercent": "5", "unitNote": null, "evidence": "5% cashback at supermarkets", "confidence": 0.9 }
  ],
  "rewardCurrency": null,
  "rewardConversion": null,
  "exchangeRateProposal": [],
  "rateProposal": [
    { "categoryId": null, "categoryName": null, "ratePercent": "1", "monthlyCap": null, "source": "STATEMENT", "evidence": "1% cashback on all purchases", "unitNote": null, "required": false },
    { "categoryId": "6f1c...", "categoryName": "Supermarkets", "ratePercent": "5", "monthlyCap": null, "source": "STATEMENT", "evidence": "5% cashback at supermarkets", "unitNote": null, "required": false },
    { "categoryId": "7a2d...", "categoryName": "Pharmacies", "ratePercent": null, "monthlyCap": null, "source": "NONE", "evidence": null, "unitNote": null, "required": true }
  ],
  "appliedRates": null,
  "conversion": { "primaryCurrency": "MXN", "requestedRate": null, "requestedRates": {}, "requestedRewardRate": null, "statementRates": [], "statementRate": null },
  "currencies": [],
  "loyalty": { "selectedBy": "ONLY_PROGRAM", "requestedProgramName": null, "selectedProgram": { "name": "Bonificacion del periodo", "unit": "CURRENCY", "accumulated": "58", "available": null, "redeemedInPeriod": null, "expiring": null, "forfeited": null }, "programs": [ { "name": "Bonificacion del periodo", "unit": "CURRENCY", "accumulated": "58", "available": null, "redeemedInPeriod": null, "expiring": null, "forfeited": null } ] },
  "breakdown": [],
  "transactions": [
    {
      "index": 0, "date": "2026-01-02", "reference": "0001", "merchant": "WAL MART SUC 123",
      "amount": "1000", "currency": "MXN", "isCredit": false, "kind": "PURCHASE",
      "convertedAmount": null, "exchangeRate": null, "exchangeRateSource": null, "excludedReason": null,
      "matchedMerchantId": "a2b9...", "matchedMerchantName": "Walmart",
      "categoryId": "6f1c...", "categoryName": "Supermarkets",
      "matchSource": "KEYWORD", "matchConfidence": null, "matchReason": null,
      "appliedRatePercent": null, "ruleApplied": false, "expectedReward": null
    }
  ],
  "warnings": [],
  "model": "claude-sonnet-5-5",
  "models": { "extraction": "claude-sonnet-5-5", "classification": "claude-haiku-5-5" },
  "createdAt": "2026-02-01T10:00:00.000Z"
}
```

Errors of step 1:

| Status | `code` | Meaning / suggested UX |
| --- | --- | --- |
| 400 | `FILE_REQUIRED` | No `file` part |
| 400 | `INVALID_PDF` | Bytes are not a PDF |
| 400 | `VALIDATION_ERROR` | Bad `cardId` / `exchangeRate` / `rewardProgramName`, or an unknown field |
| 402 | `NO_CREDITS` | Show the paywall (see section 9). `details` = the credit balance |
| 404 | `CARD_NOT_FOUND` | Card missing or not yours |
| 413 | `PAYLOAD_TOO_LARGE` | File over 10 MB |
| 415 | `UNSUPPORTED_MEDIA_TYPE` | Not `application/pdf` |
| 422 | `UNREADABLE_STATEMENT` | Not a readable credit card statement (scanned, password protected, wrong document). Ask for the original PDF from the bank |
| 429 | `TOO_MANY_REQUESTS` | Slow down |
| 502 | `EXTRACTION_FAILED` | The analysis returned an unusable result; retrying usually works |
| 503 | `EXTRACTION_UNAVAILABLE` | Analysis service busy or down; try again later |

### POST /verifications/:id/confirm  (step 2 and recalculation)

`Content-Type: application/json`. Not credit-gated and it never calls
Claude, so it can be repeated freely (`200`). Allowed on `AWAITING_RATES` and
`COMPLETED` verifications.

```json
{
  "baseRatePercent": "1",
  "categoryRates": [
    { "categoryId": "6f1c...", "ratePercent": "5", "monthlyCap": null },
    { "categoryId": "7a2d...", "ratePercent": "3", "monthlyCap": "50" }
  ],
  "saveToCard": false,
  "reportedRewardOverride": "125.40",
  "exchangeRate": "26.35",
  "exchangeRates": { "USD": "25.80", "EUR": "28.10" },
  "rewardExchangeRate": "25.80",
  "rewardProgramName": "CASH BAC CREDOMATIC"
}
```

| Field | Required | Rules |
| --- | --- | --- |
| `baseRatePercent` | yes | `0-100`, max 4 decimals. Rate for spend whose category has no entry in `categoryRates` |
| `categoryRates[]` | yes (may be `[]`) | `{ categoryId, ratePercent (0-100), monthlyCap? (> 0, 2 decimals, in the card reward unit) }`. Max 50, one per category, categories must be yours (`404 CATEGORY_NOT_FOUND`; duplicates `400 DUPLICATE_RULE_CATEGORY`). It must include every `rateProposal` entry with `required: true` (else `422 RATES_REQUIRED`) |
| `saveToCard` | no | When `true` the confirmed base rate and category rates **replace** the card's `baseRatePercent` and rules |
| `reportedRewardOverride` | no | Decimal `>= 0`, 2 decimals. The reward the bank reported, in the card reward unit; wins over the statement. Kept for later recalculations |
| `exchangeRate` | no | Legacy: one rate applied to **any** foreign currency (kept for compatibility; prefer `exchangeRates`). Replaces the one given at upload |
| `exchangeRates` | no | Object `{ "<ISO 4217>": "<rate>" }`, one rate per foreign spend currency. **Direction: units of the primary (card) currency per 1 unit of that currency.** Examples: card `HNL`, `{ "USD": "25.80" }` means 1 USD = 25.80 HNL; card `CRC`, `{ "EUR": "560" }` means 1 EUR = 560 CRC. Each rate must be `> 0` with at most 6 decimals; keys cannot be the primary currency (`400 INVALID_EXCHANGE_RATE`). Merged over the rates sent earlier; a currency without a rate is left out (warning `NO_EXCHANGE_RATE` names only that currency) |
| `rewardExchangeRate` | when `rewardConversion.required` | Same direction: **primary-currency units per 1 unit of the reward currency** (card `HNL`, reward `USD`: `"25.80"`). If the reward currency is also a foreign spend currency and `exchangeRates` has it, that rate is reused when this field is absent. Without any rate: `422 REWARD_EXCHANGE_RATE_REQUIRED`. Can be changed on every re-confirm (free recalculation) |
| `rewardProgramName` | no | As in step 1; replaces the one given at upload |

The confirmed rates **completely replace the card rules for this verification**
(a category not listed is audited at `baseRatePercent`). Values omitted in a
recalculation (`exchangeRate`, `rewardProgramName`, `reportedRewardOverride`)
keep the ones stored earlier. The response is the full verification with
`status: "COMPLETED"`:

```json
{
  "status": "COMPLETED",
  "reported": { "amount": "58", "unit": "CASHBACK_CURRENCY", "currency": "MXN", "label": "Bonificacion del periodo", "source": "STATEMENT" },
  "expected": { "amount": "58", "unit": "CASHBACK_CURRENCY", "currency": "MXN" },
  "expectedInPrimaryCurrency": "58",
  "rewardCurrency": "MXN",
  "difference": "0",
  "tolerance": "1",
  "verdict": "MATCH",
  "appliedRates": {
    "baseRatePercent": "1",
    "baseSource": "STATEMENT_CONFIRMED",
    "savedToCard": false,
    "rewardExchangeRate": null,
    "categoryRates": [
      { "categoryId": "6f1c...", "categoryName": "Supermarkets", "ratePercent": "5", "monthlyCap": null, "source": "STATEMENT_CONFIRMED" }
    ]
  },
  "conversion": { "primaryCurrency": "MXN", "requestedRate": null, "requestedRates": {}, "requestedRewardRate": null, "statementRates": [], "statementRate": null },
  "currencies": [
    { "currency": "MXN", "isPrimary": true, "spent": "1400", "eligibleSpent": "1400", "convertedEligibleSpent": "1400", "exchangeRate": null, "exchangeRateSource": null, "expectedReward": "58", "excludedCount": 0 }
  ],
  "breakdown": [
    { "categoryId": "6f1c...", "categoryName": "Supermarkets", "ratePercent": "5", "transactionCount": 3, "spend": "1100", "uncappedReward": "55", "expectedReward": "55", "monthlyCap": null, "capped": false },
    { "categoryId": null, "categoryName": null, "ratePercent": "1", "transactionCount": 1, "spend": "300", "uncappedReward": "3", "expectedReward": "3", "monthlyCap": null, "capped": false }
  ],
  "transactions": [
    {
      "index": 0, "date": "2026-01-02", "reference": "0001", "merchant": "WAL MART SUC 123",
      "amount": "1000", "currency": "MXN", "isCredit": false, "kind": "PURCHASE",
      "convertedAmount": "1000", "exchangeRate": "1", "exchangeRateSource": null, "excludedReason": null,
      "matchedMerchantId": "a2b9...", "matchedMerchantName": "Walmart",
      "categoryId": "6f1c...", "categoryName": "Supermarkets",
      "matchSource": "KEYWORD", "matchConfidence": null, "matchReason": null,
      "appliedRatePercent": "5", "ruleApplied": true, "expectedReward": "50"
    }
  ]
}
```

(other fields as in step 1, `rateProposal` included.) Errors:

| Status | `code` | Meaning / suggested UX |
| --- | --- | --- |
| 400 | `VALIDATION_ERROR` | Bad body (rates outside 0-100, unknown fields, ...) |
| 400 | `DUPLICATE_RULE_CATEGORY` | Same category twice in `categoryRates` |
| 404 | `VERIFICATION_NOT_FOUND`, `CATEGORY_NOT_FOUND` | Missing or not yours |
| 422 | `RATES_REQUIRED` | `details.missing` = `[{ categoryId, categoryName }]` required entries without a rate: ask the user and resend |
| 400 | `INVALID_EXCHANGE_RATE` | A rate in `exchangeRates` / `rewardExchangeRate` is not a positive decimal (max 6 decimals), or a key is not an ISO 4217 code other than the primary currency |
| 422 | `REWARD_EXCHANGE_RATE_REQUIRED` | The reward currency differs from the primary currency and no rate is known. `details` = `{ fromCurrency, toCurrency }` (primary, reward). Ask for `rewardExchangeRate` and resend |
| 422 | `REWARD_PROGRAM_AMBIGUOUS` | `details.programs` = names; resend with `rewardProgramName` |
| 422 | `REPORTED_REWARD_NOT_FOUND` | No usable reward figure for the chosen program (or none at all); resend with `reportedRewardOverride` |

A failed confirm leaves the verification untouched.

### PATCH /verifications/:id/transactions/:index

Body `{ "categoryId": "<uuid>" | null }`. Corrects the category of one line (for
example a wrong AI guess); `null` clears it. Only `PURCHASE`/`REFUND` lines can
be categorized (`422 TRANSACTION_NOT_CLASSIFIABLE`). The line becomes
`matchSource: "USER"` with no merchant/confidence. Returns the full verification
(with the refreshed `rateProposal`: a newly used category may now be `required`).
**It does not recompute the result**: for a `COMPLETED` verification the stored
figures stay as they were until the client calls `POST /verifications/:id/confirm`
again. Errors: `400` (bad body / negative index), `404 VERIFICATION_NOT_FOUND`,
`404 TRANSACTION_NOT_FOUND`, `404 CATEGORY_NOT_FOUND`.

### Reward currency and exchange rates

Spend and reward can be in different currencies (spend in `HNL`, "Cash Back:
$42" paid in `USD`) and a statement can mix several (`HNL` + `USD` + `EUR`).
Nothing is hardcoded per country: the extraction infers currencies from
symbols, labels and the statement's own conventions, and the server converts
with rates.

**Rate direction (everywhere): units of the PRIMARY (card) currency per 1 unit of
the other currency.** Card `HNL`, USD `25.80` -> 1 USD = 25.80 HNL. Card `CRC`,
EUR `560` -> 1 EUR = 560 CRC. Rates are `> 0`, at most 6 decimals. Rates printed
on the statement in the opposite direction are inverted by the server.

- `rewardCurrency` (verification and list items): currency of
  `reported.amount`, `expected.amount`, `difference` and `tolerance`; `null` for
  `POINTS` cards and while `AWAITING_RATES`. Effective reward currency =
  `card.rewardCurrency` ?? the chosen program's `currency` ?? the primary currency.
  For `POINTS` cards nothing is converted.
- `rewardConversion` (top level, next to `rateProposal`; `null` when no
  conversion is needed): `{ fromCurrency (primary), toCurrency (reward), rate
  (string|null), source: "STATEMENT"|"NONE", required, note }`. `rate` is
  prefilled from a rate printed on the statement; `required: true` means the app
  must ask the user for `rewardExchangeRate` before confirming. Priority at
  confirm: `rewardExchangeRate` sent > the `exchangeRates` entry of the reward
  currency > statement-printed rate > `422 REWARD_EXCHANGE_RATE_REQUIRED`.
- `exchangeRateProposal[]` (top level): one entry per foreign currency present in
  purchase/refund lines: `{ currency, rate (string|null), source:
  "STATEMENT"|"NONE", required: false }`. `required` is always `false`: a
  missing rate does not block, it only leaves that currency's lines out
  (`NO_EXCHANGE_RATE`); show the field anyway so the user can fill it.
- After confirm: `expected` is in the reward currency; `expectedInPrimaryCurrency`
  is the same figure before conversion (identical when no conversion);
  `appliedRates.rewardExchangeRate` = `{ fromCurrency, toCurrency, rate, source:
  "STATEMENT_CONFIRMED"|"USER_ENTERED" }` or `null`. `breakdown`, `currencies[]`
  and per-line `expectedReward` stay in the **primary** currency (they are
  computed before the reward conversion).
- `conversion`: `requestedRate` (legacy single rate), `requestedRates` (per
  currency, as sent), `requestedRewardRate`, `statementRates[]` (`{ from, to,
  rate, source }`, every rate printed). `statementRate` is deprecated (first of
  `statementRates` or `null`).

### Field semantics (both steps)

- `statement.*`: what was read from the PDF; any of them can be `null`.
  `currency` is the statement's main currency (null if unclear). `summaries[]`
  has one entry per currency column ("previous balance", "purchases + other
  charges", "total balance"; any figure can be `null`). `totalSpent` /
  `totalToPay` are the summary figures of the **card's primary currency**
  (`null` when absent).
- `primaryCurrency`: the card currency used for the computation.
- `reported.amount`: reward the bank says it granted. `reported.source` is
  `STATEMENT` (the chosen program's `accumulated` column) or `OVERRIDE`.
  `reported.label` is the chosen program name (`null` when none was chosen).
  `unit`/`expected.unit` is always the card's `rewardUnit` (`CASHBACK_CURRENCY`
  or `POINTS`).
- `appliedRates`: exactly the rates the verification was audited with (also for
  recalculations: it is replaced each time). `source` is `STATEMENT_CONFIRMED`
  (equal to the statement's rate), `CARD_RULE_CONFIRMED` (equal to the card's
  rate) or `USER_ENTERED`. Verifications created before this feature have
  `appliedRates: null`.
- `conversion`: see "Reward currency and exchange rates" above.
- `currencies[]` (after confirm): one entry per statement currency that has
  purchases/refunds; primary first. `spent` = net purchases minus refunds in that
  currency; `eligibleSpent` = the part used in the calculation (0 when the rate
  is missing); `convertedEligibleSpent` = that part in the primary currency;
  `exchangeRate`/`exchangeRateSource` (`REQUEST`|`STATEMENT`) are `null` for the
  primary currency or when no rate was available; `expectedReward` = sum of the
  line rewards of this currency **before monthly caps** (caps apply per category
  across currencies, so these may add up to more than `expected.amount`);
  `excludedCount` = purchase/refund lines left out for lack of a rate.
- `loyalty`: `programs[]` lists every program row of the statement (all values
  decimal strings or `null`; `unit` is `POINTS`, `CURRENCY`, `MILES` or
  `UNKNOWN`). `selectedProgram` is the audited one (or `null`); `selectedBy` is
  `REQUEST`, `CARD`, `ONLY_PROGRAM` or `null`; `requestedProgramName` is the
  name asked for. `accumulated` may be a running balance rather than earned this
  period; see `REPORTED_VALUE_MAY_BE_CUMULATIVE`.
- `explanation`: one short paragraph in Spanish written by a cheap model after
  confirm, summarizing why the verdict is `MATCH`/`UNDERPAID`/`OVERPAID`. It is
  only a narrative of numbers already computed by the server (the model never
  calculates). `null` while `AWAITING_RATES` or if it could not be generated
  (then the warning `EXPLANATION_UNAVAILABLE` is present); it is regenerated on
  every confirm.
- `expected.amount`: deterministic expected reward (after caps), in the reward
  currency's minor units (2 decimals for most currencies).
- `difference` = `reported - expected` (same decimals). **Negative means the bank
  paid less than it should have.**
- `tolerance` = `max(1, 1% of |expected|)`; differences up to and including the
  tolerance are `MATCH`.
- `verdict`:
  - `MATCH`: `|difference| <= tolerance`
  - `UNDERPAID`: `difference < -tolerance` (the user is owed money/points)
  - `OVERPAID`: `difference > tolerance`
- `breakdown[]`: one line per rate that applied plus one line with
  `categoryId: null` for spend at the base rate. Category lines first, then base.
  `spend` is net of refunds; `uncappedReward` is before the cap; `capped` is
  true when `monthlyCap` reduced the reward.
- `transactions[]`: in statement order (`index` is 0-based). `amount` is always
  positive and expressed in the line's own `currency`; `isCredit: true` means
  refund/credit (it subtracts). `reference` is the bank reference number or
  `null`. `kind` is `PURCHASE|REFUND|FEE|INTEREST|INSURANCE|PAYMENT|OTHER`.
  After confirm, `convertedAmount` is the **signed** amount in the primary
  currency (negative for credits; `null` when it could not be converted or the
  line is not a purchase/refund); `exchangeRate`/`exchangeRateSource` as in
  `currencies[]` (`"1"` for primary-currency lines, `null` source).
  `excludedReason` is `null` for lines that count, `NO_EXCHANGE_RATE` (confirm
  only) or `NON_PURCHASE_KIND` (known from step 1) otherwise; excluded lines
  have `expectedReward: "0"`, `appliedRatePercent: "0"` after confirm.
  `expectedReward` is per transaction **before caps**, rounded to 2 decimals and
  negative for credits, so the sum of lines can differ from `expected.amount`
  when a cap applied or because of rounding. `ruleApplied` is true when a
  confirmed category rate (not the base rate) set `appliedRatePercent`.
  `categoryId`/`categoryName` are the classified category.
- `warnings[]`: `{ "code": string, "message": string }`. Show them to the user.
  Codes (step 1 unless noted):
  - `CARD_LAST4_MISMATCH`: statement belongs to a different card than selected.
  - `CURRENCY_MISMATCH`: none of the statement currencies is the card currency.
  - `TOTAL_SPENT_MISMATCH`: for a currency, extracted transactions add up
    neither to the statement's "purchases + other charges" nor to the
    purchases-only figure (some may be missing; the result may be unreliable).
  - `NO_TRANSACTIONS`: no transactions found.
  - `AI_MATCHING_UNAVAILABLE`: classification failed for all or some lines;
    those lines keep keyword matches only.
  - (confirm) `NO_EXCHANGE_RATE`: foreign lines were left out because no rate
    was available; confirm again with `exchangeRate`.
  - (confirm) `EXCHANGE_RATE_APPLIED_TO_MULTIPLE_CURRENCIES`: the request
    `exchangeRate` was applied to more than one foreign currency.
  - (confirm) `REPORTED_VALUE_MAY_BE_CUMULATIVE`: the audited program's
    `accumulated` equals (about) `available + redeemedInPeriod + forfeited` and
    is more than 3x the expected reward, so it is probably a running balance. The
    verdict used it anyway; ask the user for the amount earned this period and
    confirm again with `reportedRewardOverride`.
  - (confirm) `EXPLANATION_UNAVAILABLE`: the written explanation failed; the
    result itself is unaffected.
  - (confirm) `REPORTED_UNIT_DIFFERS_FROM_CARD`: the program's unit (points vs
    money) differs from the card configuration; the card config won.
- `models`: `{ "extraction": string, "classification": string | null,
  "explanation": string | null }` - the model that performed each step;
  `classification` is `null` when no classification call was made or it failed,
  `explanation` is `null` until confirm or when it failed. `model` is deprecated and equals
  `models.extraction`.

### GET /verifications

Query: `cardId` (optional uuid; `404` if not yours), `status` (optional,
`AWAITING_RATES` or `COMPLETED`), `page` (default 1, >= 1), `pageSize`
(default 20, 1-100). Newest first. Both statuses are listed.

```json
{
  "items": [
    {
      "id": "e5f6...",
      "cardId": "c3d4...",
      "status": "COMPLETED",
      "statement": {
        "bank": "BBVA",
        "cardLast4": "4321",
        "periodStart": "2026-01-01",
        "periodEnd": "2026-01-31",
        "currency": "MXN"
      },
      "primaryCurrency": "HNL",
      "rewardUnit": "CASHBACK_CURRENCY",
      "reportedAmount": "58",
      "expectedAmount": "58",
      "difference": "0",
      "verdict": "MATCH",
      "createdAt": "2026-02-01T10:00:00.000Z"
    }
  ],
  "page": 1,
  "pageSize": 20,
  "total": 1
}
```

Items are summaries (no `breakdown`, `transactions`, `warnings`, `conversion`,
`currencies`, `loyalty` or rates); fetch the detail for those. For
`AWAITING_RATES` items `reportedAmount`, `expectedAmount`, `difference` and
`verdict` are `null`. This endpoint is **not** paywalled: users keep access to their
history after a subscription lapses.

### GET /verifications/:id

Full verification object (as in the `POST` responses, with the current
`rateProposal`). `404 VERIFICATION_NOT_FOUND`.

### DELETE /verifications/:id

`204`. `404 VERIFICATION_NOT_FOUND`.

**Abandoned uploads.** `AWAITING_RATES` verifications that are not confirmed
within 7 days (server setting `AWAITING_RATES_TTL_DAYS`) are deleted by a
periodic server job; `COMPLETED` ones are never deleted automatically. Clients
should treat a `404` on an old awaiting verification as expected.

---

## 9. Credits, subscriptions and the paywall

**Model.** Every statement analysis (`POST /verifications`, step 1) costs **one
credit**. There are three kinds of credits, spent in this order:

1. `FREE`: one lifetime credit for every new user (no purchase needed).
2. `PLAN`: 5 credits per paid billing period of the monthly subscription. They
   **do not roll over**: on each renewal what is left is expired and 5 new ones
   are granted. They only count while the period is current.
3. `PURCHASED`: consumable credit packs (e.g. 3 or 10 credits); they never expire.

The **backend is the source of truth** for the balance (it is *not* RevenueCat
virtual currency). Purchases reach the backend through RevenueCat webhooks.
Confirming, recalculating, reading and deleting verifications cost nothing.

Subscriptions and packs are sold through the stores (and web payments through
RevenueCat Web Billing / Stripe / Paddle, which need no extra client handling)
and managed by RevenueCat.

### RevenueCat app user id (required)

The backend maps RevenueCat customers to users by **app user id**. The Flutter
app **must** identify the RevenueCat customer with our user id right after
sign-in, *before* showing the paywall or making any purchase:

```dart
await Purchases.logIn(user.id);   // user.id from the /auth/* response or GET /me
```

and call `Purchases.logOut()` on logout. Purchases made while the customer is
anonymous (`$RCAnonymousID:...`) cannot be attributed to a user and are ignored
by the webhook (RevenueCat aliases are checked, so a purchase made anonymously
and then followed by `logIn` is still resolved).

The entitlement the backend checks is configured server-side
(`REVENUECAT_ENTITLEMENT_ID`, default `pro`); the app should present the offering
that grants that entitlement.

### GET /subscriptions/me

`200`:

```json
{
  "entitlementId": "pro",
  "active": true,
  "status": "ACTIVE",
  "expiresAt": "2026-03-01T10:00:00.000Z",
  "willRenew": true,
  "store": "APP_STORE",
  "productId": "pro_monthly"
}
```

- `active`: whether the user can currently use the paid features (this is the
  same check the backend applies to `POST /verifications`).
- `status`: `NONE` (never subscribed), `ACTIVE`, `CANCELLED` (auto-renew off;
  **still active until `expiresAt`**), `BILLING_ISSUE` (payment failed; still
  active until `expiresAt` while the store retries), or `EXPIRED`.
- `expiresAt`: `null` when there is no subscription (or a non-expiring one).
- `store`/`productId`: `null` when unknown.

The webhook is asynchronous: right after a purchase succeeds in the app, the
backend may take a few seconds to know. Poll `GET /subscriptions/me` (e.g. every
2 s for up to ~30 s) until `active` is true before enabling uploads; the
RevenueCat SDK's own entitlement state is fine for unlocking the UI optimistically.

### GET /credits/me

`200`:

```json
{
  "free": 0,
  "plan": 3,
  "planPeriodEnd": "2026-03-01T10:00:00.000Z",
  "purchased": 2,
  "total": 5,
  "subscriptionActive": true
}
```

- `free`, `plan`, `purchased`: credits per bucket. `plan` is only the current
  period's remaining credits; `planPeriodEnd` is when they expire (`null` when
  there are none).
- `total = free + plan + purchased`: how many analyses the user can still run.
- `subscriptionActive`: same as `GET /subscriptions/me`.`active`.

Like the subscription, purchases are asynchronous: after a purchase succeeds in
the app, poll `GET /credits/me` (e.g. every 2 s for up to ~30 s) until the
balance changes before enabling uploads.

### GET /credits/me/history

Query `page` (default 1), `pageSize` (default 20, 1-100). Newest first, append-only
ledger:

```json
{
  "items": [
    {
      "id": "b7c1...",
      "delta": -1,
      "bucket": "FREE",
      "reason": "CONSUME",
      "source": "SYSTEM",
      "verificationId": "e5f6...",
      "periodEnd": null,
      "createdAt": "2026-02-01T10:00:00.000Z"
    }
  ],
  "page": 1,
  "pageSize": 20,
  "total": 1
}
```

`bucket`: `FREE | PLAN | PURCHASED`. `reason`: `GRANT_FREE`, `GRANT_PLAN`,
`GRANT_PACK`, `CONSUME`, `REFUND` (a credit given back after a failed analysis, or
a refunded pack), `EXPIRE_PLAN` (left-over plan credits at renewal). `source`:
`APPLE | GOOGLE | WEB | SYSTEM`. `periodEnd` is set for `PLAN` entries.

### Spending credits: POST /verifications

The credit is spent **atomically and before Claude is called**
(free -> plan -> purchased); two parallel uploads can never spend the same
credit. If the analysis fails for any reason (`422`, `502`, `503`, `500`) the
credit is **refunded** to the same bucket. Invalid requests (`400`, `404`,
`413`, `415`) never reserve one. A cheap pre-check answers before the upload is
processed. With no credits:

```json
{
  "statusCode": 402,
  "code": "NO_CREDITS",
  "message": "No verification credits left. Subscribe or buy a credit pack.",
  "details": {
    "free": 0,
    "plan": 0,
    "planPeriodEnd": null,
    "purchased": 0,
    "total": 0,
    "subscriptionActive": false
  }
}
```

Show the paywall: subscription (5 credits per month) and credit packs.
`POST /verifications/:id/confirm`, `PATCH`, `GET` and `DELETE` are never gated.
In local development the gate (and all spending) can be switched off with
`CREDITS_GATE_ENABLED=false` on the server (`SUBSCRIPTION_GATE_ENABLED` is still
read as an alias when the new name is unset).

### POST /webhooks/revenuecat (server to server)

**Public**, called only by RevenueCat; not for the app. Authenticated by the
`Authorization` header, which must equal the value configured in
`REVENUECAT_WEBHOOK_AUTH` (compared in constant time; if the variable is empty
every call is rejected). Returns `401 INVALID_WEBHOOK_AUTH` otherwise.

**Subscription events** (entitlement `REVENUECAT_ENTITLEMENT_ID`):
`INITIAL_PURCHASE`, `RENEWAL`, `PRODUCT_CHANGE`, `UNCANCELLATION` (-> `ACTIVE`),
`CANCELLATION` (-> `CANCELLED`, access kept until the event's
`expiration_at_ms`), `BILLING_ISSUE` (-> `BILLING_ISSUE`, access kept until
`expiration_at_ms`), `EXPIRATION` (-> `EXPIRED`). Events are idempotent by
`event.id`, and events older than the last applied one are ignored. Purchases of a
credit pack never change the subscription.

**Credits.** In the same call the backend updates the credit ledger:

- `INITIAL_PURCHASE` / `RENEWAL` of the subscription with a future
  `expiration_at_ms`: the previous period's left-over plan credits are expired and
  `PLAN_CREDITS_PER_PERIOD` (5) are granted for the new period
  (`periodEnd = expiration_at_ms`). A period is granted only once, whatever the
  event ids.
- `NON_RENEWING_PURCHASE` (or `INITIAL_PURCHASE`) of a product configured in
  `CREDIT_PACKS` (server setting, `productId:credits` pairs such as
  `credits_3:3,credits_10:10`): grants those credits as `PURCHASED`. Idempotent by
  the store `transaction_id` (event id when absent).
- A refund of a pack (`REFUND` event, or `CANCELLATION` with
  `cancel_reason: CUSTOMER_SUPPORT`): debits the pack's credits from `PURCHASED`,
  never below zero (a pack already spent is only logged).
- The `store` maps to the ledger `source`: `APP_STORE`/`MAC_APP_STORE` -> `APPLE`,
  `PLAY_STORE` -> `GOOGLE`, `STRIPE`/`RC_BILLING`/`PADDLE` -> `WEB`, anything else
  -> `SYSTEM`.

Everything else is acknowledged and ignored.

Response `200`: `{ "status": "applied" | "duplicate" | "stale" | "ignored",
"credits": "granted" | "debited" | "duplicate" | "ignored" }`.
`400 INVALID_WEBHOOK_PAYLOAD` for bodies that are not RevenueCat events.

The app must expose the pack **product ids** configured in `CREDIT_PACKS` as
consumable products in RevenueCat/the stores.

---

## 10. Health

### GET /health  (Public)

`200`: `{ "status": "ok", "database": "up", "timestamp": "2026-01-01T00:00:00.000Z" }`.
`503` with `database: "down"` when the database is unreachable.

---

## 11. Error reference

| Status | `code` | When |
| --- | --- | --- |
| 400 | `VALIDATION_ERROR` | Body/query/path failed validation (`details` lists the rules) |
| 400 | `DUPLICATE_RULE_CATEGORY` | Two card rules for the same category (`details.categoryId`) |
| 400 | `FILE_REQUIRED`, `INVALID_PDF` | See verifications |
| 400 | `INVALID_WEBHOOK_PAYLOAD` | Webhook only |
| 401 | `INVALID_ACCESS_TOKEN` | Missing, malformed, expired or forged access token -> refresh |
| 401 | `INVALID_IDENTITY_TOKEN` | Google/Apple token rejected |
| 401 | `INVALID_REFRESH_TOKEN` | Refresh token unknown, expired, revoked or reused -> sign in again |
| 401 | `UNAUTHORIZED` | Access token valid but the account no longer exists |
| 401 | `INVALID_WEBHOOK_AUTH` | Webhook only |
| 402 | `NO_CREDITS` | Paywall (see section 9) |
| 404 | `CARD_NOT_FOUND`, `CATEGORY_NOT_FOUND`, `MERCHANT_NOT_FOUND`, `VERIFICATION_NOT_FOUND` | Missing **or not yours** |
| 409 | `CATEGORY_NAME_TAKEN`, `MERCHANT_NAME_TAKEN` | Duplicate name for this user |
| 409 | `CATEGORY_IN_USE` | Delete a category that still has merchants/card rules (`details.merchants`, `details.cardRules`) |
| 413 | `PAYLOAD_TOO_LARGE` | PDF over 10 MB |
| 415 | `UNSUPPORTED_MEDIA_TYPE` | Upload is not a PDF |
| 400 | `INVALID_EXCHANGE_RATE` | See verifications |
| 422 | `UNREADABLE_STATEMENT`, `REPORTED_REWARD_NOT_FOUND`, `REWARD_PROGRAM_AMBIGUOUS`, `REWARD_EXCHANGE_RATE_REQUIRED` | See verifications |
| 429 | `TOO_MANY_REQUESTS` | Rate limit |
| 500 | `INTERNAL_ERROR` | Unexpected; generic message, nothing leaked |
| 502 | `EXTRACTION_FAILED` | Analysis returned an unusable response |
| 503 | `IDENTITY_PROVIDER_UNAVAILABLE` | Google/Apple sign-in not configured |
| 503 | `EXTRACTION_UNAVAILABLE` | Analysis service busy/unavailable |
| 503 | (health) | Database down |

---

## 12. Changelog (breaking changes)

### Reward currency and several exchange rates

Additive unless noted (clients that ignore the new fields keep working, except
where marked **BREAKING**):

- Cards gain `rewardCurrency` (nullable ISO 4217). Loyalty `programs[]` gain
  `currency` (nullable; extraction infers it, e.g. a `$42` cash-back line next to
  local-currency spend is `USD`).
- Verification gains top-level `rewardCurrency`, `rewardConversion`,
  `exchangeRateProposal[]` and `expectedInPrimaryCurrency`; `reported`/`expected`
  gain `currency`; `appliedRates` gains `rewardExchangeRate`; `conversion` gains
  `requestedRates`, `requestedRewardRate`, `statementRates[]`
  (`conversion.statementRate` is deprecated). The list items gain
  `rewardCurrency`. The rate proposal for category rates (`rateProposal`) is
  unchanged: the new structures are siblings, not a change of its shape.
- Confirm gains `exchangeRates` (map per foreign currency) and
  `rewardExchangeRate`; `exchangeRate` stays as a legacy "any foreign currency"
  rate. New errors `422 REWARD_EXCHANGE_RATE_REQUIRED`, `400 INVALID_EXCHANGE_RATE`.
- **BREAKING (only when the reward currency differs from the card currency):**
  `expected.amount`, `difference`, `tolerance` and `reported.amount` are in the
  reward currency, no longer implicitly the card currency; read
  `rewardCurrency` to format them, and `expectedInPrimaryCurrency` for the card
  currency figure.
- Amounts are now rounded to the ISO 4217 minor units of their currency
  (previously always 2 decimals): `JPY`/`CLP` have none, `KWD` has 3.
- Rate direction is documented as "primary-currency units per 1 unit of the
  other currency" (unchanged behavior).

### Multi-currency and loyalty programs

Clients built against the previous contract must change:

- **`POST /verifications` response**
  - `transactions[]` gained `reference`, `currency`, `kind`, `convertedAmount`,
    `exchangeRate`, `exchangeRateSource`, `excludedReason`. `amount` is now in the
    line's own `currency` (not necessarily the card currency): do not sum
    `amount` across lines, use `convertedAmount`.
  - `statement.currency` is the statement's main currency and may be `null` (it
    no longer falls back to the card currency); use `primaryCurrency`.
    `statement.totalSpent` / `totalToPay` now come from the primary-currency
    summary column. New `statement.summaries[]`.
  - New top-level `primaryCurrency`, `conversion`, `currencies[]`, `loyalty`.
  - `reported.label` is the chosen loyalty program name; the value audited is the
    program's `accumulated` column (it was "reward earned this period").
  - New warning codes `NO_EXCHANGE_RATE`, `EXCHANGE_RATE_APPLIED_TO_MULTIPLE_CURRENCIES`,
    `REPORTED_VALUE_MAY_BE_CUMULATIVE`; `CURRENCY_MISMATCH` and
    `TOTAL_SPENT_MISMATCH` semantics changed (see section 8).
  - Fee, interest, insurance and payment lines are now **included** in
    `transactions[]` (with `kind` and `excludedReason: "NON_PURCHASE_KIND"`); they
    were previously dropped.
- **New request parts** `exchangeRate`, `rewardProgramName` (both optional).
- **New error** `422 REWARD_PROGRAM_AMBIGUOUS` with `details.programs`.
- **`GET /verifications` items** gained `primaryCurrency`.
- **Cards**: `currency` is now documented as the primary currency; new optional
  `rewardProgramName`.
- **Existing data**: stored verifications were migrated (every old transaction
  got `currency` = card currency, `kind` `PURCHASE`/`REFUND`, no reference;
  `loyalty.programs` is empty and `conversion.currencies` is empty for them).

### Model routing

- `GET/POST /verifications` responses gained `models` (see section 8).
  `model` is kept as a deprecated alias of `models.extraction`; read `models`.
- Existing stored verifications report `classification: null`.

### Category-level classification

- `transactions[].matchSource` is now `KEYWORD | AI_MERCHANT | AI_CATEGORY | USER | NONE`.
  **`AI` no longer exists**: it was split. Old stored rows are migrated to
  `AI_MERCHANT`; clients must handle the two new values (an `AI_CATEGORY` line
  has `matchedMerchantId: null` but a `categoryId`).
- New `transactions[].matchReason` (string or null).
- Categories with no merchants now receive AI-classified lines, so more lines get
  a category than before; the confidence threshold moved from 0.6 to 0.7
  (server setting `CLASSIFICATION_MIN_CONFIDENCE`).
- `models.classification` identifies the model that classified (null if no call
  succeeded).

### Two-step verification, rate proposal and generic extraction

- **`POST /verifications` no longer returns the audit result.** It returns a
  verification with `status: "AWAITING_RATES"`; the result (`reported`,
  `expected`, `verdict`, `breakdown`, ...) only exists after
  `POST /verifications/:id/confirm`. Until then those fields are `null`/`[]`.
  Clients must call confirm to complete (and may call it again to recalculate).
- **`POST /verifications` no longer accepts `reportedRewardOverride`** (a unknown
  part is `400`); send it to confirm.
- `422 REWARD_PROGRAM_AMBIGUOUS` and `422 REPORTED_REWARD_NOT_FOUND` are now
  raised by **confirm**, not by upload (upload stores everything and never loses
  the paid analysis).
- **New fields** in the verification: `status`, `detectedRates[]`,
  `rateProposal[]`, `appliedRates`, `loyalty.requestedProgramName`.
- **New endpoint** `POST /verifications/:id/confirm` and new error
  `422 RATES_REQUIRED` (`details.missing`).
- **`GET /verifications`**: new `status` filter and `status` in each item; items
  of `AWAITING_RATES` verifications carry `null` reward figures.
- Rates for the audit come from the user's confirmation, not directly from the
  card rules; the card rules are only the proposal (and are updated by
  `saveToCard`).
- Extraction is bank/country/format agnostic: dates and amounts of any format are
  normalized, currencies are mapped to ISO 4217 from context. `transactions[].
  merchant` is the line text exactly as printed.
- Existing data: old verifications are `COMPLETED` with `appliedRates: null`.

### Explanation, transaction correction and cleanup

- New `explanation` (string or null) in the verification and `models.explanation`
  (additive: previously `models` had two keys). New warning
  `EXPLANATION_UNAVAILABLE`.
- New endpoint `PATCH /verifications/:id/transactions/:index` and new
  `matchSource` value `USER`; new errors `404 TRANSACTION_NOT_FOUND`,
  `422 TRANSACTION_NOT_CLASSIFIABLE`.
- Abandoned `AWAITING_RATES` verifications are deleted after 7 days.

### Credits replace the subscription gate

- **`402 SUBSCRIPTION_REQUIRED` no longer exists**; `POST /verifications` answers
  `402 NO_CREDITS` (with the balance in `details`) when the user has no credits.
  Having a subscription is no longer enough or required by itself: it grants 5
  credits per period.
- Every new user gets **1 free credit**; existing users were given one too.
- A successful `POST /verifications` consumes one credit; a failed one refunds it.
- New endpoints `GET /credits/me` and `GET /credits/me/history`.
- Credit packs: configure the product ids in `CREDIT_PACKS`; purchases (including
  web payments through RevenueCat) reach the backend by webhook.
- Webhook response gained `credits`. `NON_RENEWING_PURCHASE` no longer activates
  the subscription.
- `SUBSCRIPTION_GATE_ENABLED` was renamed `CREDITS_GATE_ENABLED` (old name kept as
  alias).
