-- CreateEnum
CREATE TYPE "CreditBucket" AS ENUM ('FREE', 'PLAN', 'PURCHASED');
CREATE TYPE "CreditReason" AS ENUM ('GRANT_FREE', 'GRANT_PLAN', 'GRANT_PACK', 'CONSUME', 'REFUND', 'EXPIRE_PLAN');
CREATE TYPE "CreditSource" AS ENUM ('APPLE', 'GOOGLE', 'WEB', 'SYSTEM');

-- CreateTable
CREATE TABLE "CreditLedger" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "delta" INTEGER NOT NULL,
    "bucket" "CreditBucket" NOT NULL,
    "reason" "CreditReason" NOT NULL,
    "source" "CreditSource" NOT NULL,
    "externalRef" TEXT,
    "verificationId" UUID,
    "periodEnd" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CreditLedger_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "CreditLedger_externalRef_key" ON "CreditLedger"("externalRef");
CREATE INDEX "CreditLedger_userId_createdAt_idx" ON "CreditLedger"("userId", "createdAt" DESC);
CREATE INDEX "CreditLedger_userId_bucket_idx" ON "CreditLedger"("userId", "bucket");

-- AddForeignKey
ALTER TABLE "CreditLedger" ADD CONSTRAINT "CreditLedger_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Every existing user gets the lifetime free credit (new users get it at sign-in).
INSERT INTO "CreditLedger" ("id", "userId", "delta", "bucket", "reason", "source", "externalRef")
SELECT gen_random_uuid(), u."id", 1, 'FREE', 'GRANT_FREE', 'SYSTEM', 'free:' || u."id"::text
FROM "User" u;
