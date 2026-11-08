import { Controller, Get } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../auth/infrastructure/current-user.decorator.js';
import type { AuthenticatedUser } from '../../auth/domain/authenticated-user.js';
import { GetMeUseCase } from '../application/get-me.use-case.js';

@ApiTags('users')
@ApiBearerAuth()
@Controller('me')
export class MeController {
  constructor(private readonly getMe: GetMeUseCase) {}

  @Get()
  @ApiOkResponse({
    schema: {
      example: {
        id: '0b0e7d0e-5a43-4b6c-8a3f-3d9a0c5c1e11',
        provider: 'GOOGLE',
        email: 'ana@example.com',
        name: 'Ana Perez',
        createdAt: '2026-01-01T00:00:00.000Z',
      },
    },
  })
  async me(@CurrentUser() current: AuthenticatedUser) {
    const user = await this.getMe.execute(current.id);
    return {
      id: user.id,
      provider: user.provider,
      email: user.email,
      name: user.name,
      createdAt: user.createdAt.toISOString(),
    };
  }
}
