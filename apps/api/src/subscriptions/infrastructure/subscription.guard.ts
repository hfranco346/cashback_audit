import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import type { AuthenticatedUser } from '../../auth/domain/authenticated-user.js';
import { RequireSubscriptionUseCase } from '../application/subscription.use-cases.js';

/** Responds 402 SUBSCRIPTION_REQUIRED unless the user holds the entitlement. */
@Injectable()
export class SubscriptionGuard implements CanActivate {
  constructor(
    private readonly requireSubscription: RequireSubscriptionUseCase,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const { user } = context
      .switchToHttp()
      .getRequest<{ user: AuthenticatedUser }>();
    await this.requireSubscription.execute(user.id);
    return true;
  }
}
