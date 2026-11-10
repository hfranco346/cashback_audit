import { Body, Controller, Get, Patch } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { Decimal } from 'decimal.js';
import { CurrentUser } from '../../auth/infrastructure/current-user.decorator.js';
import type { AuthenticatedUser } from '../../auth/domain/authenticated-user.js';
import { GetMeUseCase } from '../application/get-me.use-case.js';
import {
  GetPreferencesUseCase,
  UpdatePreferencesUseCase,
} from '../application/preferences.use-cases.js';
import type { UserLocale, UserPreferences } from '../domain/preferences.js';
import { UpdatePreferencesDto } from './preferences.dto.js';

/** API values are lowercase (`auto|es|en`); the database enum is uppercase. */
const presentPreferences = (p: UserPreferences) => ({
  locale: p.locale.toLowerCase(),
  primaryCurrency: p.primaryCurrency,
  currencies: p.currencies.map((c) => ({
    code: c.code,
    lastRateToPrimary: c.lastRateToPrimary?.toString() ?? null,
    updatedAt: c.updatedAt.toISOString(),
  })),
});

@ApiTags('users')
@ApiBearerAuth()
@Controller('me')
export class MeController {
  constructor(
    private readonly getMe: GetMeUseCase,
    private readonly getPreferences: GetPreferencesUseCase,
    private readonly updatePreferences: UpdatePreferencesUseCase,
  ) {}

  @Get()
  @ApiOkResponse({
    schema: {
      example: {
        id: '0b0e7d0e-5a43-4b6c-8a3f-3d9a0c5c1e11',
        provider: 'GOOGLE',
        email: 'ana@example.com',
        name: 'Ana Perez',
        unlimitedCredits: false,
        createdAt: '2026-01-01T00:00:00.000Z',
        locale: 'auto',
        primaryCurrency: 'HNL',
        currencies: [
          {
            code: 'USD',
            lastRateToPrimary: '24.65',
            updatedAt: '2026-01-02T00:00:00.000Z',
          },
        ],
      },
    },
  })
  async me(@CurrentUser() current: AuthenticatedUser) {
    const [user, preferences] = await Promise.all([
      this.getMe.execute(current.id),
      this.getPreferences.execute(current.id),
    ]);
    return {
      id: user.id,
      provider: user.provider,
      email: user.email,
      name: user.name,
      unlimitedCredits: user.unlimitedCredits,
      createdAt: user.createdAt.toISOString(),
      ...presentPreferences(preferences),
    };
  }

  @Patch('preferences')
  @ApiOkResponse({
    description:
      'The resulting preferences: { locale, primaryCurrency, currencies }',
  })
  async patchPreferences(
    @CurrentUser() current: AuthenticatedUser,
    @Body() dto: UpdatePreferencesDto,
  ) {
    const updated = await this.updatePreferences.execute(current.id, {
      locale: dto.locale?.toUpperCase() as UserLocale | undefined,
      primaryCurrency: dto.primaryCurrency,
      currencies: dto.currencies?.map((c) => ({
        code: c.code,
        lastRateToPrimary:
          c.lastRateToPrimary === undefined
            ? undefined
            : c.lastRateToPrimary === null
              ? null
              : new Decimal(c.lastRateToPrimary),
      })),
    });
    return presentPreferences(updated);
  }
}
