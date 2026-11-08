-- Card: optional loyalty program name used to pick the program to audit.
ALTER TABLE "Card" ADD COLUMN "rewardProgramName" TEXT;

-- Verification: primary currency, per-currency summaries, conversion and loyalty info.
ALTER TABLE "Verification"
  ADD COLUMN "primaryCurrency" CHAR(3),
  ADD COLUMN "summaries" JSONB NOT NULL DEFAULT '[]',
  ADD COLUMN "conversion" JSONB NOT NULL DEFAULT '{}',
  ADD COLUMN "loyalty" JSONB NOT NULL DEFAULT '{}';

-- Backfill: existing verifications were computed in the card currency.
UPDATE "Verification" v
SET "primaryCurrency" = c."currency"
FROM "Card" c
WHERE c."id" = v."cardId";

ALTER TABLE "Verification" ALTER COLUMN "primaryCurrency" SET NOT NULL;

-- Backfill each stored transaction with currency (= card currency), kind,
-- conversion fields and no reference.
UPDATE "Verification" v
SET "transactions" = COALESCE(
  (
    SELECT jsonb_agg(
      e.t || jsonb_build_object(
        'currency', v."primaryCurrency",
        'reference', NULL,
        'kind', CASE WHEN (e.t->>'isCredit')::boolean THEN 'REFUND' ELSE 'PURCHASE' END,
        'convertedAmount', CASE WHEN (e.t->>'isCredit')::boolean THEN '-' || (e.t->>'amount') ELSE e.t->>'amount' END,
        'exchangeRate', '1',
        'rateSource', NULL,
        'excludedReason', NULL
      )
      ORDER BY e.ord
    )
    FROM jsonb_array_elements(v."transactions") WITH ORDINALITY AS e(t, ord)
  ),
  '[]'::jsonb
);

-- Old rows keep working in the new shape.
UPDATE "Verification" v
SET "conversion" = jsonb_build_object(
      'requestedRate', NULL, 'statementRate', NULL, 'currencies', '[]'::jsonb),
    "loyalty" = jsonb_build_object(
      'selected', NULL, 'selectedBy', NULL, 'programs', '[]'::jsonb);
