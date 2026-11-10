# Feature: cumulative-reward-balance

## Objective
Some banks print the reward program's cumulative balance instead of what was earned in the statement month. Derive the amount actually earned in the period and audit against that, with the least user effort.

## Why
Owner feedback (2026-11-10): one bank reports the accumulated cashback; the verdict currently treats the whole balance as earned this month, which is wrong.

## Rule (deterministic, Decimal, never the LLM)
`earned = currentBalance − previousBalance + redeemedInPeriod + expiredInPeriod` (expired = expiring/forfeited during the period as printed). Never negative-silently: if `earned < 0`, keep it and flag `REWARD_BALANCE_INCONSISTENT` warning.

## Decision order (approved: C supported by B and A)
1. **B — statement prints the previous balance** (or the earned-in-period amount): use it, source `STATEMENT`.
2. **A — card marked CUMULATIVE**: previous balance from the user's closest earlier COMPLETED verification of the same card and same program (normalized name), whose `periodEnd` <= this `periodStart` (+/- 5 days tolerance); source `PREVIOUS_VERIFICATION`.
3. **C — ask the user** in Confirm: "Is this what you earned this month or your accumulated balance?" (remembered per card). If cumulative and no previous balance: user types it (source `USER`) or uploads last month's PDF only to read that balance (source `PREVIOUS_STATEMENT`, free for the user, never stored).
- Suggestion: backend proposes `suggestedMode` with a reason code: `STATEMENT_HAS_PREVIOUS_BALANCE`, `CARD_SETTING`, `LABEL_SAYS_ACCUMULATED` (printed label like "Acumulado", "Saldo", "Disponible"), `REPORTED_FAR_ABOVE_EXPECTED` (reported > 3× expected and > a small absolute floor), or `NONE`.

## Contract
- Extraction: each loyalty program also returns `previousBalance` and `earnedInPeriod` when printed and the printed label of the audited figure (`reportedLabel`); keep the "no nullable, empty string sentinel" schema rule and the schema-size test.
- Card: `rewardReporting: "AUTO" | "MONTHLY" | "CUMULATIVE"` (default AUTO) on create/PATCH/get.
- `AWAITING_RATES` detail adds `rewardReportingProposal`: `{ mode: "MONTHLY"|"CUMULATIVE", suggestedMode, reason, cardSetting, currentBalance, previousBalance|null, previousBalanceSource: "STATEMENT"|"PREVIOUS_VERIFICATION"|null, previousVerificationId|null, redeemedInPeriod, expiredInPeriod, earned|null, previousBalanceRequired: bool }` (amounts as decimal strings in the reward unit/currency).
- `POST /verifications/:id/confirm` body adds optional `rewardReporting: { mode, previousBalance? (decimal string), previousBalanceSource? ("USER"|"PREVIOUS_STATEMENT"|"STATEMENT"|"PREVIOUS_VERIFICATION"), rememberForCard?: bool }`. When mode CUMULATIVE and no previous balance can be resolved → `422 PREVIOUS_BALANCE_REQUIRED`. `rememberForCard` updates the card's `rewardReporting`. Re-confirm (recalculate) can change it, free.
- `POST /verifications/:id/previous-statement` (multipart `file`, PDF ≤ 10 MB): reads ONLY the loyalty program balances of last month's statement with Claude (small schema), returns `200 { programs: [{ name, balance, periodEnd }], matchedBalance|null }` matched to this verification's program; no credit consumed; PDF never stored; `422 NOT_A_STATEMENT`, `422 PROGRAM_NOT_FOUND`. Throttled per user.
- COMPLETED detail adds `rewardReporting: { mode, currentBalance, previousBalance, previousBalanceSource, redeemedInPeriod, expiredInPeriod, earned }`; `reportedAmount` = earned when CUMULATIVE. The current balance is persisted so next month can use it (A).
- Spanish/English explanation mentions the derivation when CUMULATIVE.

## Constraints
- TDD off. Runners: apps/api `pnpm lint`, `pnpm build`, `pnpm test`, `pnpm test:e2e`; apps/mobile `dart format --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`.
- RDD off. Local commits on `main`; push after owner approval. Deploy API after both land.

## Tasks
- [ ] R1 Backend: extraction fields, card setting, proposal + resolution order, confirm body, previous-statement endpoint, persistence, explanation, tests, contract doc. Route: delegated.
- [ ] R2 Mobile: Confirm section (question, remembered per card, previous balance field with source label, upload last month's PDF, live breakdown), result breakdown, card form setting (advanced), tests, ES/EN. Route: delegated.
- [ ] R3 Deploy API, install builds on iPhone and Honor. Route: inline.

## Progress / evidence
