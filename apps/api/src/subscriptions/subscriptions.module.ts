import { Module } from '@nestjs/common';
import { UsersModule } from '../users/users.module.js';
import {
  GetMySubscriptionUseCase,
  HandleRevenueCatWebhookUseCase,
} from './application/subscription.use-cases.js';
import { SubscriptionRepository } from './domain/subscription.repository.js';
import { PrismaSubscriptionRepository } from './infrastructure/prisma-subscription.repository.js';
import { SubscriptionsController } from './infrastructure/subscriptions.controller.js';

@Module({
  imports: [UsersModule],
  controllers: [SubscriptionsController],
  providers: [
    GetMySubscriptionUseCase,
    HandleRevenueCatWebhookUseCase,
    { provide: SubscriptionRepository, useClass: PrismaSubscriptionRepository },
  ],
  exports: [GetMySubscriptionUseCase, HandleRevenueCatWebhookUseCase],
})
export class SubscriptionsModule {}
