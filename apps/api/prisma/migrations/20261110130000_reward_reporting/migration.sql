-- CreateEnum
CREATE TYPE "RewardReporting" AS ENUM ('AUTO', 'MONTHLY', 'CUMULATIVE');

-- AlterTable
ALTER TABLE "Card" ADD COLUMN     "rewardReporting" "RewardReporting" NOT NULL DEFAULT 'AUTO';

-- AlterTable
ALTER TABLE "Verification" ADD COLUMN     "rewardReporting" JSONB;
