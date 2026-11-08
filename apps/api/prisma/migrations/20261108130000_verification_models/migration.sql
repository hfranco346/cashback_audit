-- Which model performed each step of a verification.
ALTER TABLE "Verification" ADD COLUMN "models" JSONB NOT NULL DEFAULT '{}';

-- Backfill: old rows only used the extraction model (and the legacy AI matcher
-- used the same model); classification is unknown.
UPDATE "Verification"
SET "models" = jsonb_build_object('extraction', "model", 'classification', NULL);
