-- AlterTable
ALTER TABLE "Card" ADD COLUMN     "rewardCap" DECIMAL(14,2);

-- The card-wide reward cap per statement must be positive when set.
ALTER TABLE "Card" ADD CONSTRAINT "Card_rewardCap_positive" CHECK ("rewardCap" IS NULL OR "rewardCap" > 0);
