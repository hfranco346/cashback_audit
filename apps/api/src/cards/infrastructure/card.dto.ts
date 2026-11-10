import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsEmail,
  IsISO4217CurrencyCode,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  MaxLength,
  ValidateNested,
} from 'class-validator';
import { DecimalField } from '../../shared/http/decimal-validation.js';

const trim = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;
const upper = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim().toUpperCase() : value;

const upperOrNull = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim().toUpperCase() || null : value;

const emailOrNull = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim().toLowerCase() || null : value;

const RATE = { min: '0', max: '100', maxDecimals: 4 } as const;
const CAP = {
  min: '0',
  max: '1000000000',
  minInclusive: false,
  maxDecimals: 2,
} as const;
const POINTS = {
  min: '0',
  max: '1000',
  minInclusive: false,
  maxDecimals: 4,
} as const;

export class CardRuleDto {
  @ApiProperty()
  @IsUUID()
  categoryId!: string;

  @ApiProperty({
    example: '5',
    description:
      'Percent of spend (0-100, up to 4 decimals). Number or string accepted.',
  })
  @DecimalField(RATE)
  ratePercent!: string;

  @ApiPropertyOptional({
    example: '500',
    nullable: true,
    description:
      'Max reward per statement period from this rule, in the card reward unit (> 0, 2 decimals)',
  })
  @IsOptional()
  @DecimalField(CAP)
  monthlyCap?: string | null;
}

export class CreateCardDto {
  @ApiProperty({ example: 'Daily card' })
  @Transform(trim)
  @IsString()
  @IsNotEmpty()
  @MaxLength(60)
  alias!: string;

  @ApiProperty({ example: 'BBVA' })
  @Transform(trim)
  @IsString()
  @IsNotEmpty()
  @MaxLength(60)
  bank!: string;

  @ApiProperty({
    example: '4321',
    description: 'Exactly 4 digits. Never send the full card number.',
  })
  @Matches(/^\d{4}$/, { message: 'last4 must be exactly 4 digits' })
  last4!: string;

  @ApiPropertyOptional({ example: 'VISA', nullable: true })
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(30)
  network?: string | null;

  @ApiProperty({ enum: ['CASHBACK_CURRENCY', 'POINTS'] })
  @IsEnum(['CASHBACK_CURRENCY', 'POINTS'])
  rewardUnit!: 'CASHBACK_CURRENCY' | 'POINTS';

  @ApiPropertyOptional({
    example: '1',
    description:
      'Points per currency unit of reward (POINTS cards). Default 1.',
  })
  @IsOptional()
  @DecimalField(POINTS)
  pointsPerCurrencyUnit?: string;

  @ApiProperty({
    example: '1',
    description: 'Base reward rate in percent, applied when no rule matches',
  })
  @DecimalField(RATE)
  baseRatePercent!: string;

  @ApiProperty({
    example: 'HNL',
    description:
      'ISO 4217 code of the card primary currency; rewards, rates and caps are expressed in it',
  })
  @Transform(upper)
  @IsISO4217CurrencyCode()
  currency!: string;

  @ApiPropertyOptional({
    example: 'CASH BAC CREDOMATIC',
    nullable: true,
    description:
      'Loyalty program to audit when the statement lists several (case/accent-insensitive "contains" match)',
  })
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(80)
  rewardProgramName?: string | null;

  @ApiPropertyOptional({
    example: 'USD',
    nullable: true,
    description:
      'ISO 4217 currency the reward is paid in when it differs from `currency` (e.g. spend in HNL, cashback in USD). Overrides what the statement indicates; null = detect from the statement.',
  })
  @IsOptional()
  @Transform(upperOrNull)
  @IsISO4217CurrencyCode()
  rewardCurrency?: string | null;

  @ApiPropertyOptional({
    example: 'reclamos@banco.com',
    nullable: true,
    description:
      'Where claims to the bank are sent (valid email, lowercased); null clears it',
  })
  @IsOptional()
  @Transform(emailOrNull)
  @IsEmail()
  @MaxLength(254)
  claimEmail?: string | null;

  @ApiPropertyOptional({
    enum: ['AUTO', 'MONTHLY', 'CUMULATIVE'],
    description:
      'How the bank prints the reward: MONTHLY = earned this month, CUMULATIVE = running balance, AUTO (default) = ask per statement',
  })
  @IsOptional()
  @IsEnum(['AUTO', 'MONTHLY', 'CUMULATIVE'])
  rewardReporting?: 'AUTO' | 'MONTHLY' | 'CUMULATIVE';

  @ApiPropertyOptional({ type: [CardRuleDto] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => CardRuleDto)
  rules?: CardRuleDto[];
}

export class UpdateCardDto {
  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @IsNotEmpty()
  @MaxLength(60)
  alias?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @IsNotEmpty()
  @MaxLength(60)
  bank?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Matches(/^\d{4}$/, { message: 'last4 must be exactly 4 digits' })
  last4?: string;

  @ApiPropertyOptional({ nullable: true })
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(30)
  network?: string | null;

  @ApiPropertyOptional({ enum: ['CASHBACK_CURRENCY', 'POINTS'] })
  @IsOptional()
  @IsEnum(['CASHBACK_CURRENCY', 'POINTS'])
  rewardUnit?: 'CASHBACK_CURRENCY' | 'POINTS';

  @ApiPropertyOptional()
  @IsOptional()
  @DecimalField(POINTS)
  pointsPerCurrencyUnit?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @DecimalField(RATE)
  baseRatePercent?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(upper)
  @IsISO4217CurrencyCode()
  currency?: string;

  @ApiPropertyOptional({ nullable: true })
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(80)
  rewardProgramName?: string | null;

  @ApiPropertyOptional({
    example: 'USD',
    nullable: true,
    description:
      'ISO 4217 currency the reward is paid in when it differs from `currency` (e.g. spend in HNL, cashback in USD). Overrides what the statement indicates; null = detect from the statement.',
  })
  @IsOptional()
  @Transform(upperOrNull)
  @IsISO4217CurrencyCode()
  rewardCurrency?: string | null;

  @ApiPropertyOptional({
    example: 'reclamos@banco.com',
    nullable: true,
    description:
      'Where claims to the bank are sent (valid email, lowercased); null clears it',
  })
  @IsOptional()
  @Transform(emailOrNull)
  @IsEmail()
  @MaxLength(254)
  claimEmail?: string | null;

  @ApiPropertyOptional({
    enum: ['AUTO', 'MONTHLY', 'CUMULATIVE'],
    description:
      'How the bank prints the reward: MONTHLY = earned this month, CUMULATIVE = running balance, AUTO (default) = ask per statement',
  })
  @IsOptional()
  @IsEnum(['AUTO', 'MONTHLY', 'CUMULATIVE'])
  rewardReporting?: 'AUTO' | 'MONTHLY' | 'CUMULATIVE';

  @ApiPropertyOptional({
    type: [CardRuleDto],
    description: 'When present, REPLACES all rules',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => CardRuleDto)
  rules?: CardRuleDto[];
}
