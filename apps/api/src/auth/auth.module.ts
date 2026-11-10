import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Env } from '../config/env.js';
import { CreditsModule } from '../credits/credits.module.js';
import { UsersModule } from '../users/users.module.js';
import { AuthSessionService } from './application/auth-session.service.js';
import {
  LogoutUseCase,
  RefreshTokensUseCase,
} from './application/session.use-cases.js';
import {
  OtpCodec,
  SignInWithEmailUseCase,
  StartEmailLoginUseCase,
} from './application/email-login.use-cases.js';
import {
  SignInWithAppleUseCase,
  SignInWithGoogleUseCase,
} from './application/sign-in.use-case.js';
import { EmailLoginCodeRepository } from './domain/email-login-code.repository.js';
import { EmailSender } from './domain/email-sender.js';
import {
  AppleIdTokenVerifier,
  GoogleIdTokenVerifier,
} from './domain/identity-token-verifier.js';
import { RefreshTokenRepository } from './domain/refresh-token.repository.js';
import { TokenService } from './domain/token-service.js';
import { JoseAppleIdTokenVerifier } from './infrastructure/apple-id-token.verifier.js';
import { AuthController } from './infrastructure/auth.controller.js';
import { GoogleOAuthIdTokenVerifier } from './infrastructure/google-id-token.verifier.js';
import { LogEmailSender } from './infrastructure/log-email.sender.js';
import { ResendEmailSender } from './infrastructure/resend-email.sender.js';
import { PrismaEmailLoginCodeRepository } from './infrastructure/prisma-email-login-code.repository.js';
import { JoseTokenService } from './infrastructure/jose-token.service.js';
import { JwtAuthGuard } from './infrastructure/jwt-auth.guard.js';
import { PrismaRefreshTokenRepository } from './infrastructure/prisma-refresh-token.repository.js';

@Module({
  imports: [UsersModule, CreditsModule],
  controllers: [AuthController],
  providers: [
    AuthSessionService,
    SignInWithGoogleUseCase,
    SignInWithAppleUseCase,
    OtpCodec,
    StartEmailLoginUseCase,
    SignInWithEmailUseCase,
    RefreshTokensUseCase,
    LogoutUseCase,
    JwtAuthGuard,
    {
      provide: EmailSender,
      inject: [ConfigService],
      useFactory: (config: ConfigService<Env, true>) =>
        config.get('EMAIL_PROVIDER', { infer: true }) === 'resend'
          ? new ResendEmailSender(config)
          : new LogEmailSender(config),
    },
    {
      provide: EmailLoginCodeRepository,
      useClass: PrismaEmailLoginCodeRepository,
    },
    { provide: TokenService, useClass: JoseTokenService },
    { provide: RefreshTokenRepository, useClass: PrismaRefreshTokenRepository },
    { provide: GoogleIdTokenVerifier, useClass: GoogleOAuthIdTokenVerifier },
    { provide: AppleIdTokenVerifier, useClass: JoseAppleIdTokenVerifier },
  ],
  exports: [TokenService, JwtAuthGuard],
})
export class AuthModule {}
