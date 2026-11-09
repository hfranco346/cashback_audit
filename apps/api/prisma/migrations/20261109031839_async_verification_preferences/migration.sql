-- CreateEnum
CREATE TYPE "UserLocale" AS ENUM ('AUTO', 'ES', 'EN');

-- CreateEnum
CREATE TYPE "VerificationFailureCode" AS ENUM ('NOT_A_STATEMENT', 'EXTRACTION_FAILED', 'INTERRUPTED');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "VerificationStatus" ADD VALUE 'PROCESSING';
ALTER TYPE "VerificationStatus" ADD VALUE 'FAILED';

-- AlterTable
ALTER TABLE "User" ADD COLUMN     "locale" "UserLocale" NOT NULL DEFAULT 'AUTO',
ADD COLUMN     "primaryCurrency" CHAR(3);

-- AlterTable
ALTER TABLE "Verification" ADD COLUMN     "failureCode" "VerificationFailureCode",
ADD COLUMN     "processedAt" TIMESTAMP(3),
ADD COLUMN     "processingStartedAt" TIMESTAMP(3),
ADD COLUMN     "seenAt" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "UserCurrency" (
    "userId" UUID NOT NULL,
    "code" CHAR(3) NOT NULL,
    "lastRateToPrimary" DECIMAL(16,6),
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "UserCurrency_pkey" PRIMARY KEY ("userId","code")
);

-- CreateIndex
CREATE INDEX "Verification_userId_seenAt_idx" ON "Verification"("userId", "seenAt");

-- AddForeignKey
ALTER TABLE "UserCurrency" ADD CONSTRAINT "UserCurrency_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Results that existed before the "seen" marker count as already seen.
UPDATE "Verification" SET "seenAt" = "createdAt" WHERE "status" = 'COMPLETED';
