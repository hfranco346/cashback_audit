import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { Type } from 'class-transformer';
import { CardRuleDto } from '../../cards/infrastructure/card.dto.js';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsEnum,
  ValidateNested,
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

export class ConfirmVerificationDto {
  @ApiProperty({
    example: '1',
    description: 'Base rate in percent (0-100) for spend with no category rate',
  })
  @DecimalField({ min: '0', max: '100', maxDecimals: 4 })
  baseRatePercent!: string;

  @ApiProperty({
    type: [CardRuleDto],
    description:
      'Rate per category; must include every category marked required in rateProposal',
  })
  @IsArray()
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => CardRuleDto)
  categoryRates!: CardRuleDto[];

  @ApiPropertyOptional({
    default: false,
    description: 'Also save these rates as the card rates',
  })
  @IsOptional()
  @IsBoolean()
  saveToCard?: boolean;

  @ApiPropertyOptional({ example: '125.40' })
  @IsOptional()
  @DecimalField({ min: '0', max: '1000000000000', maxDecimals: 2 })
  reportedRewardOverride?: string;

  @ApiPropertyOptional({ example: '26.35' })
  @IsOptional()
  @DecimalField({
    min: '0',
    max: '1000000',
    minInclusive: false,
    maxDecimals: 6,
  })
  exchangeRate?: string;

  @ApiPropertyOptional({ example: 'CASH BAC CREDOMATIC' })
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  rewardProgramName?: string;
}

export class ListVerificationsQuery {
  @ApiPropertyOptional({ enum: ['AWAITING_RATES', 'COMPLETED'] })
  @IsOptional()
  @IsEnum(['AWAITING_RATES', 'COMPLETED'])
  status?: 'AWAITING_RATES' | 'COMPLETED';

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
