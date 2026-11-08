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
| `rules` | array | optional, max 50, **one rule per category** |

Rule (`rules[]`):

| Field | Type | Rules |
| --- | --- | --- |
| `categoryId` | uuid | required, must be one of your categories (`404 CATEGORY_NOT_FOUND`); duplicates are `400 DUPLICATE_RULE_CATEGORY` |
| `ratePercent` | decimal | required, `0-100`, max 4 decimals |
| `monthlyCap` | decimal or null | optional, `> 0`, max 2 decimals. Maximum reward obtainable from this rule per statement period, **in the card's reward unit** (currency for cashback cards, points for `POINTS` cards). `null`/absent = no cap |

How the expected reward is computed (so the UI can explain it): for each
transaction the rate is the card rule of the transaction's category if the
card has one, otherwise `baseRatePercent`. Refunds/credits subtract. Lines in a
foreign currency are first converted into the card currency. For
`POINTS` cards the reward is multiplied by `pointsPerCurrencyUnit`. Each rule's
total for the statement is then limited to its `monthlyCap`. The final amount is
rounded to 2 decimals (half up).

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

A verification audits one statement: the user uploads the PDF, the backend has
Claude read it, computes the reward the card *should* have earned and compares it
with the reward the bank reported.

**The PDF is processed in memory and discarded; only extracted results are
stored.**

### POST /verifications

`Content-Type: multipart/form-data` with these parts:

| Part | Required | Notes |
| --- | --- | --- |
| `file` | yes | The statement PDF. `application/pdf` only, max **10 MB** (10 485 760 bytes). The content must really be a PDF |
| `cardId` | yes | UUID of one of your cards |
| `reportedRewardOverride` | no | Decimal string (>= 0, max 2 decimals), e.g. `"125.40"`. The reward the bank reported, in the card's reward unit. Overrides what was read from the statement. Use it when the statement shows no reward figure (`REPORTED_REWARD_NOT_FOUND`), the user says it was read wrong, or the "Acumulados" column is a running balance (`REPORTED_VALUE_MAY_BE_CUMULATIVE`) |
| `exchangeRate` | no | Decimal string `> 0`, max 6 decimals, e.g. `"26.35"`: how many units of the **card currency** one unit of the foreign currency is worth (foreign -> primary). Wins over a rate printed on the statement. Applied to every foreign currency on the statement |
| `rewardProgramName` | no | 1-80 chars. Loyalty program to audit (same matching as the card field); overrides the card's `rewardProgramName`. Send it to resolve `422 REWARD_PROGRAM_AMBIGUOUS`. An empty value is ignored |

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
subscription (`402`) -> upload type/size (`415`/`413`) -> field validation
(`400`) -> PDF signature (`400 INVALID_PDF`) -> card ownership (`404`) ->
analysis (`422`/`502`/`503`).

**Multi-currency.** Statements can have one amount column per currency (e.g.
Lempiras and Dolares). Every transaction carries its own `currency` (ISO 4217).
Lines in the card's primary currency are used as is. Foreign lines are converted
into it with, in this order: (1) the request `exchangeRate`, (2) the rate printed
on the statement (`conversion.statementRate`; a rate printed in the opposite
direction is inverted), (3) none. With no rate the request still **succeeds**:
the expected reward is computed on the primary-currency lines only, the foreign
lines come back with `excludedReason: "NO_EXCHANGE_RATE"` and the warning
`NO_EXCHANGE_RATE` is added; the client can offer the user to retry with
`exchangeRate`.

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
with `details.programs` (array of names): let the user pick and retry with the
`rewardProgramName` form field. If `reportedRewardOverride` is sent the
ambiguity does not block the request (`loyalty.selectedProgram` is then `null`).
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
3. **No match** (`matchSource: "NONE"`): the line earns the card's base rate.

Lines that are not purchases (`kind` other than `PURCHASE`/`REFUND`) are never
classified. If classification fails (fully or for some lines) the verification
still succeeds using keyword matches and carries the warning
`AI_MATCHING_UNAVAILABLE`.

`201` response (full verification object):

```json
{
  "id": "e5f6...",
  "cardId": "c3d4...",
  "statement": {
    "bank": "BBVA",
    "cardLast4": "4321",
    "periodStart": "2026-01-01",
    "periodEnd": "2026-01-31",
    "currency": "HNL",
    "totalSpent": "1400",
    "totalToPay": "1400",
    "summaries": [
      { "currency": "HNL", "previousBalance": "0", "purchasesAndCharges": "1400", "totalBalance": "1400" },
      { "currency": "USD", "previousBalance": "0", "purchasesAndCharges": "10", "totalBalance": "10" }
    ]
  },
  "primaryCurrency": "HNL",
  "reported": {
    "amount": "58",
    "unit": "CASHBACK_CURRENCY",
    "label": "CASH BAC CREDOMATIC",
    "source": "STATEMENT"
  },
  "expected": { "amount": "58", "unit": "CASHBACK_CURRENCY" },
  "difference": "0",
  "tolerance": "1",
  "verdict": "MATCH",
  "conversion": {
    "primaryCurrency": "HNL",
    "requestedRate": "26.35",
    "statementRate": null
  },
  "currencies": [
    {
      "currency": "HNL",
      "isPrimary": true,
      "spent": "1400",
      "eligibleSpent": "1400",
      "convertedEligibleSpent": "1400",
      "exchangeRate": null,
      "exchangeRateSource": null,
      "expectedReward": "56",
      "excludedCount": 0
    },
    {
      "currency": "USD",
      "isPrimary": false,
      "spent": "10",
      "eligibleSpent": "10",
      "convertedEligibleSpent": "263.5",
      "exchangeRate": "26.35",
      "exchangeRateSource": "REQUEST",
      "expectedReward": "2.64",
      "excludedCount": 0
    }
  ],
  "loyalty": {
    "selectedBy": "CARD",
    "selectedProgram": {
      "name": "CASH BAC CREDOMATIC",
      "unit": "CURRENCY",
      "accumulated": "58",
      "available": "58",
      "redeemedInPeriod": null,
      "expiring": null,
      "forfeited": null
    },
    "programs": [
      {
        "name": "PUNTOS BAC CREDOMATIC",
        "unit": "POINTS",
        "accumulated": "1500",
        "available": "1400",
        "redeemedInPeriod": "100",
        "expiring": null,
        "forfeited": "0"
      },
      {
        "name": "CASH BAC CREDOMATIC",
        "unit": "CURRENCY",
        "accumulated": "58",
        "available": "58",
        "redeemedInPeriod": null,
        "expiring": null,
        "forfeited": null
      }
    ]
  },
  "breakdown": [
    {
      "categoryId": "6f1c...",
      "categoryName": "Supermarkets",
      "ratePercent": "5",
      "transactionCount": 3,
      "spend": "1100",
      "uncappedReward": "55",
      "expectedReward": "55",
      "monthlyCap": null,
      "capped": false
    },
    {
      "categoryId": null,
      "categoryName": null,
      "ratePercent": "1",
      "transactionCount": 1,
      "spend": "300",
      "uncappedReward": "3",
      "expectedReward": "3",
      "monthlyCap": null,
      "capped": false
    }
  ],
  "transactions": [
    {
      "index": 0,
      "date": "2026-01-02",
      "reference": "000123",
      "merchant": "WAL MART SUC 123",
      "amount": "1000",
      "currency": "HNL",
      "isCredit": false,
      "kind": "PURCHASE",
      "convertedAmount": "1000",
      "exchangeRate": "1",
      "exchangeRateSource": null,
      "excludedReason": null,
      "matchedMerchantId": "a2b9...",
      "matchedMerchantName": "Walmart",
      "categoryId": "6f1c...",
      "categoryName": "Supermarkets",
      "matchSource": "KEYWORD",
      "matchConfidence": null,
      "matchReason": null,
      "appliedRatePercent": "5",
      "ruleApplied": true,
      "expectedReward": "50"
    }
  ],
  "warnings": [],
  "model": "claude-sonnet-5-5",
  "models": { "extraction": "claude-sonnet-5-5", "classification": "claude-haiku-5-5" },
  "createdAt": "2026-02-01T10:00:00.000Z"
}
```

Field semantics:

- `statement.*`: what was read from the PDF; any of them can be `null`.
  `currency` is the statement's main currency (null if unclear). `summaries[]`
  has one entry per currency column ("Saldo anterior", "Compras + otros cargos",
  "Saldo total"; any figure can be `null`). `totalSpent` / `totalToPay` are the
  summary figures of the **card's primary currency** (`null` when absent).
- `primaryCurrency`: the card currency used for the computation.
- `reported.amount`: reward the bank says it granted this period.
  `reported.source` is `STATEMENT` (the chosen program's `accumulated` column) or
  `OVERRIDE` (`reportedRewardOverride`). `reported.label` is the chosen program
  name (`null` when none was chosen). `unit`/`expected.unit` is always the card's
  `rewardUnit` (`CASHBACK_CURRENCY` or `POINTS`).
- `conversion`: `requestedRate` (the `exchangeRate` you sent, or `null`) and
  `statementRate` (`{ from, to, rate, source: "STATEMENT" }` or `null`).
- `currencies[]`: one entry per statement currency that has purchases/refunds;
  primary first. `spent` = net purchases minus refunds in that currency;
  `eligibleSpent` = the part used in the calculation (0 when the rate is
  missing); `convertedEligibleSpent` = that part in the primary currency;
  `exchangeRate`/`exchangeRateSource` (`REQUEST`|`STATEMENT`) are `null` for the
  primary currency or when no rate was available; `expectedReward` = sum of the
  line rewards of this currency **before monthly caps** (caps apply per category
  across currencies, so these may add up to more than `expected.amount`);
  `excludedCount` = purchase/refund lines left out for lack of a rate.
- `loyalty`: `programs[]` lists every program row of the statement (all values
  decimal strings or `null`; `unit` is `POINTS`, `CURRENCY`, `MILES` or
  `UNKNOWN`). `selectedProgram` is the audited one (or `null`); `selectedBy` is
  `REQUEST`, `CARD`, `ONLY_PROGRAM` or `null`. `accumulated` may be a running
  balance rather than earned this period; see `REPORTED_VALUE_MAY_BE_CUMULATIVE`.
- `expected.amount`: deterministic expected reward (after caps), 2 decimals.
- `difference` = `reported - expected` (2 decimals). **Negative means the bank
  paid less than it should have.**
- `tolerance` = `max(1, 1% of |expected|)`; differences up to and including the
  tolerance are `MATCH`.
- `verdict`:
  - `MATCH`: `|difference| <= tolerance`
  - `UNDERPAID`: `difference < -tolerance` (the user is owed money/points)
  - `OVERPAID`: `difference > tolerance`
- `breakdown[]`: one line per card rule that applied plus one line with
  `categoryId: null` for spend at the base rate. Rule lines first, then base.
  `spend` is net of refunds; `uncappedReward` is before the cap; `capped` is
  true when `monthlyCap` reduced the reward.
- `transactions[]`: in statement order (`index` is 0-based). `amount` is always
  positive and expressed in the line's own `currency`; `isCredit: true` means
  refund/credit (it subtracts). `reference` is the bank reference number or
  `null`. `kind` is `PURCHASE|REFUND|FEE|INTEREST|INSURANCE|PAYMENT|OTHER`.
  `convertedAmount` is the **signed** amount in the primary currency (negative
  for credits; `null` when it could not be converted or the line is not a
  purchase/refund); `exchangeRate`/`exchangeRateSource` as in `currencies[]`
  (`"1"` for primary-currency lines, `null` source). `excludedReason` is `null`
  for lines that counted, `NO_EXCHANGE_RATE` or `NON_PURCHASE_KIND` otherwise
  (excluded lines have `expectedReward: "0"`, `appliedRatePercent: "0"` and no
  category).
  `expectedReward` is per transaction **before caps**, rounded to 2 decimals and
  negative for credits, so the sum of lines can differ from `expected.amount`
  when a cap applied or because of rounding. `ruleApplied` is true when a card
  rule (not the base rate) set `appliedRatePercent`.
  `categoryId`/`categoryName` are the matched merchant's category (even when the
  card has no rule for it).
- `warnings[]`: `{ "code": string, "message": string }`. Show them to the user.
  Codes:
  - `CARD_LAST4_MISMATCH`: statement belongs to a different card than selected.
  - `CURRENCY_MISMATCH`: none of the statement currencies is the card currency.
  - `NO_EXCHANGE_RATE`: foreign lines were left out because no rate was
    available; retry with `exchangeRate`.
  - `EXCHANGE_RATE_APPLIED_TO_MULTIPLE_CURRENCIES`: the request `exchangeRate`
    was applied to more than one foreign currency.
  - `REPORTED_VALUE_MAY_BE_CUMULATIVE`: the audited program's `accumulated`
    equals (about) `available + redeemedInPeriod + forfeited` and is more than
    3x the expected reward, so it is probably a running balance. The verdict used
    it anyway; ask the user for the amount earned this period and retry with
    `reportedRewardOverride`.
  - `REPORTED_UNIT_DIFFERS_FROM_CARD`: the statement's reward unit
    (points vs money) differs from the card configuration; the card config won.
  - `TOTAL_SPENT_MISMATCH`: for a currency, extracted transactions add up
    neither to the statement's "Compras + otros cargos" nor to the purchases-only
    figure (some may be missing; the result may be unreliable).
  - `NO_TRANSACTIONS`: no transactions found.
  - `AI_MATCHING_UNAVAILABLE`: classification failed for all or some lines;
    those lines keep keyword matches only.
- `models`: `{ "extraction": string, "classification": string | null }` - the
  model that performed each step; `classification` is `null` when no
  classification call was made or it failed. `model` is deprecated and equals
  `models.extraction`.

Errors specific to this endpoint:

| Status | `code` | Meaning / suggested UX |
| --- | --- | --- |
| 400 | `FILE_REQUIRED` | No `file` part |
| 400 | `INVALID_PDF` | Bytes are not a PDF |
| 400 | `VALIDATION_ERROR` | Bad `cardId` / `reportedRewardOverride` / `exchangeRate` / `rewardProgramName` |
| 402 | `SUBSCRIPTION_REQUIRED` | Show the paywall (see section 9). `details.entitlementId` |
| 404 | `CARD_NOT_FOUND` | Card missing or not yours |
| 413 | `PAYLOAD_TOO_LARGE` | File over 10 MB |
| 415 | `UNSUPPORTED_MEDIA_TYPE` | Not `application/pdf` |
| 422 | `UNREADABLE_STATEMENT` | Not a readable credit card statement (scanned, password protected, wrong document). Ask for the original PDF from the bank |
| 422 | `REPORTED_REWARD_NOT_FOUND` | The statement shows no usable reward figure for the chosen program. Ask the user to type it and retry with `reportedRewardOverride` |
| 422 | `REWARD_PROGRAM_AMBIGUOUS` | Several loyalty programs and none chosen/matched. `details.programs` is the list of names; let the user pick one and retry with the `rewardProgramName` form field |
| 429 | `TOO_MANY_REQUESTS` | Slow down |
| 502 | `EXTRACTION_FAILED` | The analysis returned an unusable result; retrying usually works |
| 503 | `EXTRACTION_UNAVAILABLE` | Analysis service busy or down; try again later |

### GET /verifications

Query: `cardId` (optional uuid; `404` if not yours), `page` (default 1, >= 1),
`pageSize` (default 20, 1-100). Newest first.

```json
{
  "items": [
    {
      "id": "e5f6...",
      "cardId": "c3d4...",
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
`currencies` or `loyalty`); fetch the
detail for those. This endpoint is **not** paywalled: users keep access to their
history after a subscription lapses.

### GET /verifications/:id

Full verification object (as in the `POST` response). `404 VERIFICATION_NOT_FOUND`.

### DELETE /verifications/:id

`204`. `404 VERIFICATION_NOT_FOUND`.

---

## 9. Subscriptions and the paywall

Subscriptions are sold through the stores and managed by RevenueCat. The backend
learns about them through RevenueCat webhooks and gates `POST /verifications`.

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

### POST /verifications gate

Without an active entitlement, `POST /verifications` returns:

```json
{
  "statusCode": 402,
  "code": "SUBSCRIPTION_REQUIRED",
  "message": "An active subscription is required to verify statements",
  "details": { "entitlementId": "pro" }
}
```

In local development the gate can be switched off with
`SUBSCRIPTION_GATE_ENABLED=false` on the server.

### POST /webhooks/revenuecat (server to server)

**Public**, called only by RevenueCat; not for the app. Authenticated by the
`Authorization` header, which must equal the value configured in
`REVENUECAT_WEBHOOK_AUTH` (compared in constant time; if the variable is empty
every call is rejected). Returns `401 INVALID_WEBHOOK_AUTH` otherwise.

Handled event types: `INITIAL_PURCHASE`, `RENEWAL`, `PRODUCT_CHANGE`,
`UNCANCELLATION`, `NON_RENEWING_PURCHASE` (-> `ACTIVE`), `CANCELLATION` (->
`CANCELLED`, access kept until the event's `expiration_at_ms`), `BILLING_ISSUE`
(-> `BILLING_ISSUE`, access kept until `expiration_at_ms`), `EXPIRATION` (->
`EXPIRED`). Everything else is acknowledged and ignored. Events are idempotent
by `event.id`, and events older than the last applied one are ignored.

Response `200`: `{ "status": "applied" | "duplicate" | "stale" | "ignored" }`.
`400 INVALID_WEBHOOK_PAYLOAD` for bodies that are not RevenueCat events.

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
| 402 | `SUBSCRIPTION_REQUIRED` | Paywall |
| 404 | `CARD_NOT_FOUND`, `CATEGORY_NOT_FOUND`, `MERCHANT_NOT_FOUND`, `VERIFICATION_NOT_FOUND` | Missing **or not yours** |
| 409 | `CATEGORY_NAME_TAKEN`, `MERCHANT_NAME_TAKEN` | Duplicate name for this user |
| 409 | `CATEGORY_IN_USE` | Delete a category that still has merchants/card rules (`details.merchants`, `details.cardRules`) |
| 413 | `PAYLOAD_TOO_LARGE` | PDF over 10 MB |
| 415 | `UNSUPPORTED_MEDIA_TYPE` | Upload is not a PDF |
| 422 | `UNREADABLE_STATEMENT`, `REPORTED_REWARD_NOT_FOUND`, `REWARD_PROGRAM_AMBIGUOUS` | See verifications |
| 429 | `TOO_MANY_REQUESTS` | Rate limit |
| 500 | `INTERNAL_ERROR` | Unexpected; generic message, nothing leaked |
| 502 | `EXTRACTION_FAILED` | Analysis returned an unusable response |
| 503 | `IDENTITY_PROVIDER_UNAVAILABLE` | Google/Apple sign-in not configured |
| 503 | `EXTRACTION_UNAVAILABLE` | Analysis service busy/unavailable |
| 503 | (health) | Database down |

---

## 12. Changelog (breaking changes)

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

- `transactions[].matchSource` is now `KEYWORD | AI_MERCHANT | AI_CATEGORY | NONE`.
  **`AI` no longer exists**: it was split. Old stored rows are migrated to
  `AI_MERCHANT`; clients must handle the two new values (an `AI_CATEGORY` line
  has `matchedMerchantId: null` but a `categoryId`).
- New `transactions[].matchReason` (string or null).
- Categories with no merchants now receive AI-classified lines, so more lines get
  a category than before; the confidence threshold moved from 0.6 to 0.7
  (server setting `CLASSIFICATION_MIN_CONFIDENCE`).
- `models.classification` identifies the model that classified (null if no call
  succeeded).
