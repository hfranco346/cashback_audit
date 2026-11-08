import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  Post,
} from '@nestjs/common';
import { ApiBearerAuth, ApiExcludeEndpoint, ApiTags } from '@nestjs/swagger';
import { SkipThrottle } from '@nestjs/throttler';
import type { AuthenticatedUser } from '../../auth/domain/authenticated-user.js';
import { CurrentUser } from '../../auth/infrastructure/current-user.decorator.js';
import { Public } from '../../auth/infrastructure/public.decorator.js';
import {
  GetMySubscriptionUseCase,
  HandleRevenueCatWebhookUseCase,
} from '../application/subscription.use-cases.js';
import { parseRevenueCatPayload } from './revenuecat-event.schema.js';

@ApiTags('subscriptions')
@Controller()
export class SubscriptionsController {
  constructor(
    private readonly getMySubscription: GetMySubscriptionUseCase,
    private readonly webhook: HandleRevenueCatWebhookUseCase,
  ) {}

  @Get('subscriptions/me')
  @ApiBearerAuth()
  async me(@CurrentUser() user: AuthenticatedUser) {
    const view = await this.getMySubscription.execute(user.id);
    return { ...view, expiresAt: view.expiresAt?.toISOString() ?? null };
  }

  /** Called by RevenueCat only; authenticated by the shared Authorization value. */
  @Post('webhooks/revenuecat')
  @Public()
  @SkipThrottle({ default: true, strict: true })
  @HttpCode(200)
  @ApiExcludeEndpoint()
  async revenueCat(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: unknown,
  ) {
    this.webhook.assertAuthorized(authorization);
    const event = parseRevenueCatPayload(body);
    if (!event) {
      throw new BadRequestException({
        code: 'INVALID_WEBHOOK_PAYLOAD',
        message: 'Unrecognized RevenueCat payload',
      });
    }
    return { status: await this.webhook.execute(event) };
  }
}
