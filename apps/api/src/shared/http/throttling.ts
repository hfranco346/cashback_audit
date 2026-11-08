import { Injectable, SetMetadata } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';

export const STRICT_THROTTLE_KEY = 'strictThrottle';

/** Marks a route for the stricter `strict` throttler (e.g. paid AI calls). */
export const StrictThrottle = () => SetMetadata(STRICT_THROTTLE_KEY, true);

/** Rate limits per authenticated user when available, else per IP. */
@Injectable()
export class UserAwareThrottlerGuard extends ThrottlerGuard {
  protected override getTracker(req: Record<string, any>): Promise<string> {
    return Promise.resolve(
      req.user?.id ? `user:${req.user.id}` : String(req.ip),
    );
  }
}
