import { Module } from '@nestjs/common';
import { CreditsModule } from '../credits/credits.module.js';
import { UsersModule } from '../users/users.module.js';
import { AuthSessionService } from './application/auth-session.service.js';
import {
  LogoutUseCase,
  RefreshTokensUseCase,
} from './application/session.use-cases.js';
import {
  SignInWithAppleUseCase,
  SignInWithGoogleUseCase,
} from './application/sign-in.use-case.js';
import {
  AppleIdTokenVerifier,
  GoogleIdTokenVerifier,
} from './domain/identity-token-verifier.js';
import { RefreshTokenRepository } from './domain/refresh-token.repository.js';
import { TokenService } from './domain/token-service.js';
import { JoseAppleIdTokenVerifier } from './infrastructure/apple-id-token.verifier.js';
import { AuthController } from './infrastructure/auth.controller.js';
import { GoogleOAuthIdTokenVerifier } from './infrastructure/google-id-token.verifier.js';
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
    RefreshTokensUseCase,
    LogoutUseCase,
    JwtAuthGuard,
    { provide: TokenService, useClass: JoseTokenService },
    { provide: RefreshTokenRepository, useClass: PrismaRefreshTokenRepository },
    { provide: GoogleIdTokenVerifier, useClass: GoogleOAuthIdTokenVerifier },
    { provide: AppleIdTokenVerifier, useClass: JoseAppleIdTokenVerifier },
  ],
  exports: [TokenService, JwtAuthGuard],
})
export class AuthModule {}
