import { Body, Controller, Get, HttpCode, Post, Req } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Request } from 'express';
import type { Env } from '../../config/env.js';
import { OtpThrottle } from '../../shared/http/throttling.js';
import { ApiAcceptedResponse, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import {
  SignInWithEmailUseCase,
  StartEmailLoginUseCase,
} from '../application/email-login.use-cases.js';
import {
  SignInWithAppleUseCase,
  SignInWithGoogleUseCase,
  type SignInResult,
} from '../application/sign-in.use-case.js';
import {
  LogoutUseCase,
  RefreshTokensUseCase,
} from '../application/session.use-cases.js';
import {
  AppleSignInDto,
  EmailStartDto,
  EmailVerifyDto,
  GoogleSignInDto,
  RefreshDto,
} from './auth.dto.js';
import { Public } from './public.decorator.js';

const signInResponse = (result: SignInResult) => ({
  ...result.tokens,
  user: {
    id: result.user.id,
    email: result.user.email,
    name: result.user.name,
  },
});

@ApiTags('auth')
@Public()
@Controller('auth')
export class AuthController {
  constructor(
    private readonly googleSignIn: SignInWithGoogleUseCase,
    private readonly appleSignIn: SignInWithAppleUseCase,
    private readonly refresh: RefreshTokensUseCase,
    private readonly logoutUseCase: LogoutUseCase,
    private readonly emailStart: StartEmailLoginUseCase,
    private readonly emailSignIn: SignInWithEmailUseCase,
    private readonly config: ConfigService<Env, true>,
  ) {}

  @Get('providers')
  @ApiOkResponse({ description: 'Which sign-in methods this server offers' })
  providers() {
    return {
      email: true,
      google:
        this.config.get('GOOGLE_CLIENT_IDS', { infer: true }).trim() !== '',
      apple: this.config.get('APPLE_BUNDLE_ID', { infer: true }).trim() !== '',
    };
  }

  @Post('email/start')
  @OtpThrottle()
  @HttpCode(202)
  @ApiAcceptedResponse({
    description: 'A code was sent (always, for valid emails)',
  })
  async startEmail(@Body() dto: EmailStartDto, @Req() req: Request) {
    return this.emailStart.execute(dto.email, dto.locale, req.ip ?? null);
  }

  @Post('email/verify')
  @OtpThrottle()
  @HttpCode(200)
  @ApiOkResponse({ description: 'Access + refresh tokens and the user' })
  async verifyEmail(@Body() dto: EmailVerifyDto) {
    return signInResponse(await this.emailSignIn.execute(dto.email, dto.code));
  }

  @Post('google')
  @HttpCode(200)
  @ApiOkResponse({ description: 'Access + refresh tokens and the user' })
  async google(@Body() dto: GoogleSignInDto) {
    return signInResponse(await this.googleSignIn.execute(dto.idToken));
  }

  @Post('apple')
  @HttpCode(200)
  @ApiOkResponse({ description: 'Access + refresh tokens and the user' })
  async apple(@Body() dto: AppleSignInDto) {
    return signInResponse(
      await this.appleSignIn.execute(dto.identityToken, dto.fullName),
    );
  }

  @Post('refresh')
  @HttpCode(200)
  @ApiOkResponse({
    description: 'Rotated token pair; the old refresh token is now invalid',
  })
  async refreshTokens(@Body() dto: RefreshDto) {
    return this.refresh.execute(dto.refreshToken);
  }

  @Post('logout')
  @HttpCode(204)
  async logout(@Body() dto: RefreshDto): Promise<void> {
    await this.logoutUseCase.execute(dto.refreshToken);
  }
}
