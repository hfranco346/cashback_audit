import { Controller, Get } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { AuthenticatedUser } from '../../auth/domain/authenticated-user.js';
import { CurrentUser } from '../../auth/infrastructure/current-user.decorator.js';
import { GetMySubscriptionUseCase } from '../application/subscription.use-cases.js';

@ApiTags('subscriptions')
@Controller()
export class SubscriptionsController {
  constructor(private readonly getMySubscription: GetMySubscriptionUseCase) {}

  @Get('subscriptions/me')
  @ApiBearerAuth()
  async me(@CurrentUser() user: AuthenticatedUser) {
    const view = await this.getMySubscription.execute(user.id);
    return { ...view, expiresAt: view.expiresAt?.toISOString() ?? null };
  }
}
