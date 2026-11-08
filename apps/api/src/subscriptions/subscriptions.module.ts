import { Module } from '@nestjs/common';
import { UsersModule } from '../users/users.module.js';
import {
  GetMySubscriptionUseCase,
  HandleRevenueCatWebhookUseCase,
  RequireSubscriptionUseCase,
} from './application/subscription.use-cases.js';
import { SubscriptionRepository } from './domain/subscription.repository.js';
import { PrismaSubscriptionRepository } from './infrastructure/prisma-subscription.repository.js';
import { SubscriptionGuard } from './infrastructure/subscription.guard.js';
import { SubscriptionsController } from './infrastructure/subscriptions.controller.js';

@Module({
  imports: [UsersModule],
  controllers: [SubscriptionsController],
  providers: [
    GetMySubscriptionUseCase,
    HandleRevenueCatWebhookUseCase,
    RequireSubscriptionUseCase,
    SubscriptionGuard,
    { provide: SubscriptionRepository, useClass: PrismaSubscriptionRepository },
  ],
  // Exported so other modules can use `@UseGuards(SubscriptionGuard)`.
  exports: [RequireSubscriptionUseCase, SubscriptionGuard],
})
export class SubscriptionsModule {}
