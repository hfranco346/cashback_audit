import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerModule } from '@nestjs/throttler';
import { validateEnv, type Env } from './config/env.js';
import { AuthModule } from './auth/auth.module.js';
import { JwtAuthGuard } from './auth/infrastructure/jwt-auth.guard.js';
import { CardsModule } from './cards/cards.module.js';
import { CategoriesModule } from './categories/categories.module.js';
import { CreditsModule } from './credits/credits.module.js';
import { SubscriptionsModule } from './subscriptions/subscriptions.module.js';
import { UsersModule } from './users/users.module.js';
import { HealthController } from './health/health.controller.js';
import {
  OTP_THROTTLE_KEY,
  STRICT_THROTTLE_KEY,
  UserAwareThrottlerGuard,
} from './shared/http/throttling.js';
import { VerificationsModule } from './verifications/verifications.module.js';
import { PrismaModule } from './shared/prisma/prisma.module.js';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, validate: validateEnv }),
    ThrottlerModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService<Env, true>) => {
        const ttl = config.get('THROTTLE_TTL_SECONDS', { infer: true }) * 1000;
        return [
          {
            name: 'default',
            ttl,
            limit: config.get('THROTTLE_LIMIT', { infer: true }),
          },
          {
            // Only applies to routes tagged with @StrictThrottle().
            name: 'strict',
            ttl,
            limit: config.get('VERIFICATION_THROTTLE_LIMIT', { infer: true }),
            skipIf: (context) =>
              !Reflect.getMetadata(STRICT_THROTTLE_KEY, context.getHandler()),
          },
          {
            // Only applies to routes tagged with @OtpThrottle(); keyed by IP.
            name: 'otp',
            ttl,
            limit: config.get('OTP_THROTTLE_LIMIT', { infer: true }),
            skipIf: (context) =>
              !Reflect.getMetadata(OTP_THROTTLE_KEY, context.getHandler()),
          },
        ];
      },
    }),
    PrismaModule,
    UsersModule,
    AuthModule,
    CategoriesModule,
    CardsModule,
    SubscriptionsModule,
    CreditsModule,
    VerificationsModule,
  ],
  controllers: [HealthController],
  providers: [
    // Order matters: authenticate first so the throttler can key on the user.
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: UserAwareThrottlerGuard },
  ],
})
export class AppModule {}
