import { Module } from '@nestjs/common';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module.js';
import { CreditsService } from './application/credits.service.js';
import { RevenueCatCreditsUseCase } from './application/revenuecat-credits.use-case.js';
import { CreditLedgerRepository } from './domain/credit-ledger.repository.js';
import { CreditsController } from './infrastructure/credits.controller.js';
import { CreditsGuard } from './infrastructure/credits.guard.js';
import { PrismaCreditLedgerRepository } from './infrastructure/prisma-credit-ledger.repository.js';
import { RevenueCatWebhookController } from './infrastructure/revenuecat-webhook.controller.js';

@Module({
  imports: [SubscriptionsModule],
  controllers: [CreditsController, RevenueCatWebhookController],
  providers: [
    CreditsService,
    CreditsGuard,
    RevenueCatCreditsUseCase,
    { provide: CreditLedgerRepository, useClass: PrismaCreditLedgerRepository },
  ],
  exports: [CreditsService, CreditsGuard],
})
export class CreditsModule {}
