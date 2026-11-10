-- AlterTable
ALTER TABLE "User" ADD COLUMN "unlimitedCredits" BOOLEAN NOT NULL DEFAULT false;

-- AlterTable
ALTER TABLE "Card" ADD COLUMN "claimEmail" TEXT;
