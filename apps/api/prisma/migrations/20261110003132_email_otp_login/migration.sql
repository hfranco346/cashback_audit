-- AlterEnum
ALTER TYPE "AuthProvider" ADD VALUE 'EMAIL';

-- CreateTable
CREATE TABLE "EmailLoginCode" (
    "id" UUID NOT NULL,
    "email" TEXT NOT NULL,
    "codeHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "consumedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ip" TEXT,

    CONSTRAINT "EmailLoginCode_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "EmailLoginCode_email_createdAt_idx" ON "EmailLoginCode"("email", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "EmailLoginCode_createdAt_idx" ON "EmailLoginCode"("createdAt");
