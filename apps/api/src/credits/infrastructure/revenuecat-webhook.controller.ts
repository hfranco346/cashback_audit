import {
  BadRequestException,
  Body,
  Controller,
  Headers,
  HttpCode,
  Post,
} from '@nestjs/common';
import { ApiExcludeEndpoint, ApiTags } from '@nestjs/swagger';
import { SkipThrottle } from '@nestjs/throttler';
import { Public } from '../../auth/infrastructure/public.decorator.js';
import { HandleRevenueCatWebhookUseCase } from '../../subscriptions/application/subscription.use-cases.js';
import { parseRevenueCatPayload } from '../../subscriptions/infrastructure/revenuecat-event.schema.js';
import { RevenueCatCreditsUseCase } from '../application/revenuecat-credits.use-case.js';

@ApiTags('subscriptions')
@Controller()
export class RevenueCatWebhookController {
  constructor(
    private readonly subscriptions: HandleRevenueCatWebhookUseCase,
    private readonly credits: RevenueCatCreditsUseCase,
  ) {}

  /**
   * Called by RevenueCat only; authenticated by the shared Authorization
   * value. Updates the subscription state, then the credit ledger. Both parts
   * are idempotent, so a retried delivery is safe.
   */
  @Post('webhooks/revenuecat')
  @Public()
  @SkipThrottle({ default: true, strict: true })
  @HttpCode(200)
  @ApiExcludeEndpoint()
  async revenueCat(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: unknown,
  ) {
    this.subscriptions.assertAuthorized(authorization);
    const event = parseRevenueCatPayload(body);
    if (!event) {
      throw new BadRequestException({
        code: 'INVALID_WEBHOOK_PAYLOAD',
        message: 'Unrecognized RevenueCat payload',
      });
    }
    const status = await this.subscriptions.execute(event);
    const credits = await this.credits.execute(event);
    return { status, credits };
  }
}
