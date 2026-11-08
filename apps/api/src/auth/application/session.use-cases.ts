import { Injectable } from '@nestjs/common';
import { AuthSessionService, type AuthTokens } from './auth-session.service.js';

@Injectable()
export class RefreshTokensUseCase {
  constructor(private readonly sessions: AuthSessionService) {}

  execute(refreshToken: string): Promise<AuthTokens> {
    return this.sessions.rotate(refreshToken);
  }
}

@Injectable()
export class LogoutUseCase {
  constructor(private readonly sessions: AuthSessionService) {}

  execute(refreshToken: string): Promise<void> {
    return this.sessions.revoke(refreshToken);
  }
}
