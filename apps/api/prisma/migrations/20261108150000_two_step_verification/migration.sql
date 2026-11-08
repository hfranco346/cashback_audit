-- CreateEnum
CREATE TYPE "VerificationStatus" AS ENUM ('AWAITING_RATES', 'COMPLETED');

-- Existing verifications are complete.
ALTER TABLE "Verification"
  ADD COLUMN "status" "VerificationStatus" NOT NULL DEFAULT 'COMPLETED',
  ADD COLUMN "detectedRates" JSONB NOT NULL DEFAULT '[]',
  ADD COLUMN "appliedRates" JSONB,
  ADD COLUMN "explanation" TEXT,
  ALTER COLUMN "reportedAmount" DROP NOT NULL,
  ALTER COLUMN "reportedSource" DROP NOT NULL,
  ALTER COLUMN "expectedAmount" DROP NOT NULL,
  ALTER COLUMN "difference" DROP NOT NULL,
  ALTER COLUMN "tolerance" DROP NOT NULL,
  ALTER COLUMN "verdict" DROP NOT NULL;

-- appliedRates stays NULL for verifications made before rates were recorded.

-- CreateIndex
CREATE INDEX "Verification_userId_status_createdAt_idx" ON "Verification"("userId", "status", "createdAt" DESC);
