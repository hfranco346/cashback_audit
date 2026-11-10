import { Controller, Get, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';
import type { AuthenticatedUser } from '../../auth/domain/authenticated-user.js';
import { CurrentUser } from '../../auth/infrastructure/current-user.decorator.js';
import { CreditsService } from '../application/credits.service.js';

export class CreditHistoryQuery {
  @ApiPropertyOptional({ default: 1, minimum: 1 })
  @IsOptional()
  @Transform(({ value }) => (value === undefined ? value : Number(value)))
  @IsInt()
  @Min(1)
  page: number = 1;

  @ApiPropertyOptional({ default: 20, minimum: 1, maximum: 100 })
  @IsOptional()
  @Transform(({ value }) => (value === undefined ? value : Number(value)))
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize: number = 20;
}

@ApiTags('credits')
@ApiBearerAuth()
@Controller('credits')
export class CreditsController {
  constructor(private readonly credits: CreditsService) {}

  @Get('me')
  async me(@CurrentUser() user: AuthenticatedUser) {
    await this.credits.grantFree(user.id);
    const b = await this.credits.balance(user.id);
    return {
      free: b.free,
      plan: b.plan,
      planPeriodEnd: b.planPeriodEnd?.toISOString() ?? null,
      purchased: b.purchased,
      total: b.total,
      subscriptionActive: b.subscriptionActive,
      unlimited: b.unlimited,
    };
  }

  @Get('me/history')
  async history(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: CreditHistoryQuery,
  ) {
    const result = await this.credits.history(
      user.id,
      query.page,
      query.pageSize,
    );
    return {
      items: result.items.map((e) => ({
        id: e.id,
        delta: e.delta,
        bucket: e.bucket,
        reason: e.reason,
        source: e.source,
        verificationId: e.verificationId,
        periodEnd: e.periodEnd?.toISOString() ?? null,
        createdAt: e.createdAt.toISOString(),
      })),
      page: result.page,
      pageSize: result.pageSize,
      total: result.total,
    };
  }
}
