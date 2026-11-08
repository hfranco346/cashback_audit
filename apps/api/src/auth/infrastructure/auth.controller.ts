import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { ApiOkResponse, ApiTags } from '@nestjs/swagger';
import {
  SignInWithAppleUseCase,
  SignInWithGoogleUseCase,
  type SignInResult,
} from '../application/sign-in.use-case.js';
import {
  LogoutUseCase,
  RefreshTokensUseCase,
} from '../application/session.use-cases.js';
import { AppleSignInDto, GoogleSignInDto, RefreshDto } from './auth.dto.js';
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
  ) {}

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
