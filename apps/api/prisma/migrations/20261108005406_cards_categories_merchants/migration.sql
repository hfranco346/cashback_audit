-- CreateEnum
CREATE TYPE "RewardUnit" AS ENUM ('CASHBACK_CURRENCY', 'POINTS');

-- CreateTable
CREATE TABLE "Card" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "alias" TEXT NOT NULL,
    "bank" TEXT NOT NULL,
    "last4" CHAR(4) NOT NULL,
    "network" TEXT,
    "rewardUnit" "RewardUnit" NOT NULL,
    "pointsPerCurrencyUnit" DECIMAL(12,4) NOT NULL DEFAULT 1,
    "baseRatePercent" DECIMAL(7,4) NOT NULL,
    "currency" CHAR(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Card_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MerchantCategory" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MerchantCategory_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Merchant" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "keywords" TEXT[],
    "categoryId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Merchant_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CardRule" (
    "id" UUID NOT NULL,
    "cardId" UUID NOT NULL,
    "categoryId" UUID NOT NULL,
    "ratePercent" DECIMAL(7,4) NOT NULL,
    "monthlyCap" DECIMAL(14,2),

    CONSTRAINT "CardRule_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Card_userId_idx" ON "Card"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "MerchantCategory_userId_name_key" ON "MerchantCategory"("userId", "name");

-- CreateIndex
CREATE INDEX "Merchant_categoryId_idx" ON "Merchant"("categoryId");

-- CreateIndex
CREATE UNIQUE INDEX "Merchant_userId_name_key" ON "Merchant"("userId", "name");

-- CreateIndex
CREATE INDEX "CardRule_categoryId_idx" ON "CardRule"("categoryId");

-- CreateIndex
CREATE UNIQUE INDEX "CardRule_cardId_categoryId_key" ON "CardRule"("cardId", "categoryId");

-- AddForeignKey
ALTER TABLE "Card" ADD CONSTRAINT "Card_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MerchantCategory" ADD CONSTRAINT "MerchantCategory_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Merchant" ADD CONSTRAINT "Merchant_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Merchant" ADD CONSTRAINT "Merchant_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "MerchantCategory"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CardRule" ADD CONSTRAINT "CardRule_cardId_fkey" FOREIGN KEY ("cardId") REFERENCES "Card"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CardRule" ADD CONSTRAINT "CardRule_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "MerchantCategory"("id") ON DELETE CASCADE ON UPDATE CASCADE;
