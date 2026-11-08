-- CreateEnum
CREATE TYPE "Verdict" AS ENUM ('MATCH', 'UNDERPAID', 'OVERPAID');

-- CreateEnum
CREATE TYPE "ReportedSource" AS ENUM ('STATEMENT', 'OVERRIDE');

-- CreateTable
CREATE TABLE "Verification" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "cardId" UUID NOT NULL,
    "statementBank" TEXT,
    "statementLast4" TEXT,
    "periodStart" DATE,
    "periodEnd" DATE,
    "currency" CHAR(3),
    "totalSpent" DECIMAL(16,2),
    "totalToPay" DECIMAL(16,2),
    "reportedAmount" DECIMAL(16,2) NOT NULL,
    "reportedUnit" "RewardUnit" NOT NULL,
    "reportedLabel" TEXT,
    "reportedSource" "ReportedSource" NOT NULL,
    "expectedAmount" DECIMAL(16,2) NOT NULL,
    "difference" DECIMAL(16,2) NOT NULL,
    "tolerance" DECIMAL(16,2) NOT NULL,
    "verdict" "Verdict" NOT NULL,
    "breakdown" JSONB NOT NULL,
    "transactions" JSONB NOT NULL,
    "warnings" JSONB NOT NULL,
    "model" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Verification_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Verification_userId_createdAt_idx" ON "Verification"("userId", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "Verification_cardId_createdAt_idx" ON "Verification"("cardId", "createdAt" DESC);

-- AddForeignKey
ALTER TABLE "Verification" ADD CONSTRAINT "Verification_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Verification" ADD CONSTRAINT "Verification_cardId_fkey" FOREIGN KEY ("cardId") REFERENCES "Card"("id") ON DELETE CASCADE ON UPDATE CASCADE;
