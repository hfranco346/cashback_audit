import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import type { AuthenticatedUser } from '../../auth/domain/authenticated-user.js';
import { CreditsService } from '../application/credits.service.js';

/**
 * Responds 402 NO_CREDITS before the upload is processed when the user has
 * nothing to spend. Not binding: the credit is spent atomically later.
 */
@Injectable()
export class CreditsGuard implements CanActivate {
  constructor(private readonly credits: CreditsService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const { user } = context
      .switchToHttp()
      .getRequest<{ user: AuthenticatedUser }>();
    await this.credits.assertHasCredits(user.id);
    return true;
  }
}
