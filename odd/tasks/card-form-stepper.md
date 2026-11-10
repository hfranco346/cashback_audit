# Feature: card-form-stepper

## Objective
Owner feedback (2026-11-10): the card form is long and confusing. Rebuild it as a 4-step Stepper, remove the redundant "Programa a auditar" field, replace cramped category dropdowns with a full-name bottom-sheet picker, and add the card-wide reward cap per statement (the owner's banks cap globally, not per category).

## Contract
- Card `rewardCap`: decimal string or null, in the card's reward unit/currency (same unit as the reward), max reward per statement period for the whole card. Create/PATCH/get. Applied by the deterministic calculator AFTER summing all categories (and after per-rule caps); the excess is dropped. Completed detail adds `rewardCapApplied: { cap, uncapped, capped }` or null; explanation mentions it; `audit` keeps per-line rewards uncapped (the cap is shown at the total).
- Reward program selection: the card's existing program-name field (whatever it is called today, e.g. `rewardProgramName`) stays in the API but leaves the creation form. When a statement has several loyalty programs and the card has no program set, the AWAITING_RATES detail exposes `rewardProgramChoice: { required: true, options: [{ name, unit, currency, reportedLabel }] }`; confirm body accepts `rewardProgramName` + `rememberForCard` (reuse the same remember flag semantics as rewardReporting or a separate `rememberProgramForCard`), recomputes the audit with that program and, if remembered, saves it on the card. With one program it is chosen automatically.
- Stepper (mobile): 1 Card (bank, alias, last 4, card currency, live card preview) · 2 Reward (what it gives: money/points/miles, reward currency, how the bank reports: monthly/cumulative/auto, card cap per statement) · 3 Categories & % (rules with the sheet picker, base rate) · 4 Review (summary + Save). Editing opens the same Stepper with free navigation between steps; per-step validation; Back/Next always visible.
- Category picker: tapping the category of a rule (and the category field in the merchant sheet and the reassign dialog) opens a bottom sheet listing all categories with full names (wrapping), search when > 8, selected state with check, and "Crear rubro" at the end (creates inline and selects it).

## Constraints
- Keep the visual language of `docs/cashback-audit-design` (HANDOFF tokens, components in `lib/core/ui`).
- TDD off. Runners: apps/api `pnpm lint`, `pnpm build`, `pnpm test`, `pnpm test:e2e`; apps/mobile `dart format --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`.
- RDD off. Local commits on `main`; push after owner approval.

## Tasks
- [x] S1 Backend: card rewardCap + calculator + detail/explanation; program choice proposal + confirm + remember; tests; contract. Route: delegated.
- [ ] S2 Mobile: Stepper card form, category sheet picker (3 places), cap field, program choice in Confirm, tests, ES/EN. Route: delegated.
- [ ] S3 Deploy API; install iOS + Android builds on the owner's devices (production API). Route: inline.

## Progress / evidence
- S1 (delegated, backend writer): migration `20261110140000_card_reward_cap` applied to dev DB; commits: feat(api) cap + program choice, docs(api) contract. apps/api: `pnpm lint` clean, `pnpm build` ok, `pnpm test` 418/418, `pnpm test:e2e` 201/201 (incl. 14 new in card-cap-program.e2e-spec.ts). Contract: `docs/api-contract.md` sections 7, 8, 12.
