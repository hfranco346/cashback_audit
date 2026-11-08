-- matchSource 'AI' was split into AI_MERCHANT (registered merchant) and
-- AI_CATEGORY (category only). Old AI matches always named a merchant.
UPDATE "Verification" v
SET "transactions" = (
  SELECT COALESCE(
    jsonb_agg(
      CASE WHEN e.t->>'matchSource' = 'AI'
        THEN e.t || jsonb_build_object('matchSource', 'AI_MERCHANT')
        ELSE e.t END
      ORDER BY e.ord
    ),
    '[]'::jsonb
  )
  FROM jsonb_array_elements(v."transactions") WITH ORDINALITY AS e(t, ord)
)
WHERE v."transactions"::text LIKE '%"matchSource": "AI"%';
