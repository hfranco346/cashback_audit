import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsInt, IsOptional, IsUUID, Max, Min } from 'class-validator';
import { DecimalField } from '../../shared/http/decimal-validation.js';

export class CreateVerificationDto {
  @ApiProperty({ description: 'Card the statement belongs to' })
  @IsUUID()
  cardId!: string;

  @ApiPropertyOptional({
    example: '125.40',
    description:
      'Reward reported by the bank, when the statement does not show it or Claude misread it. Overrides the extracted value.',
  })
  @IsOptional()
  @DecimalField({ min: '0', max: '1000000000000', maxDecimals: 2 })
  reportedRewardOverride?: string;
}

export class ListVerificationsQuery {
  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  cardId?: string;

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
