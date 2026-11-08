import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import {
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
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

  @ApiPropertyOptional({
    example: '24.65',
    description:
      'Exchange rate foreign -> card currency (1 unit of the foreign currency in the card currency). Wins over the rate printed on the statement.',
  })
  @IsOptional()
  @DecimalField({
    min: '0',
    max: '1000000',
    minInclusive: false,
    maxDecimals: 6,
  })
  exchangeRate?: string;

  @ApiPropertyOptional({
    example: 'CASH BAC CREDOMATIC',
    description:
      'Loyalty program to audit; overrides the card rewardProgramName. Send it to resolve a 422 REWARD_PROGRAM_AMBIGUOUS.',
  })
  @IsOptional()
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() || undefined : value,
  )
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  rewardProgramName?: string;
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
