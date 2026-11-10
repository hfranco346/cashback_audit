import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { Type } from 'class-transformer';
import { CardRuleDto } from '../../cards/infrastructure/card.dto.js';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsEnum,
  ValidateNested,
  ValidateIf,
  IsInt,
  IsNotEmpty,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { PREVIOUS_BALANCE_SOURCES } from '../domain/reward-reporting.js';
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

export class RewardReportingDto {
  @ApiProperty({
    enum: ['MONTHLY', 'CUMULATIVE'],
    description:
      'MONTHLY: the printed figure is what was earned this month. CUMULATIVE: it is a running balance; the earned amount is derived from the previous balance.',
  })
  @IsEnum(['MONTHLY', 'CUMULATIVE'])
  mode!: 'MONTHLY' | 'CUMULATIVE';

  @ApiPropertyOptional({
    example: '120.50',
    description:
      'Reward balance at the end of the previous statement (CUMULATIVE). Wins over the statement and the previous audit.',
  })
  @IsOptional()
  @DecimalField({ min: '0', max: '1000000000000', maxDecimals: 6 })
  previousBalance?: string;

  @ApiPropertyOptional({
    enum: PREVIOUS_BALANCE_SOURCES,
    description:
      'Where previousBalance came from (default USER; use PREVIOUS_STATEMENT when read with POST /verifications/:id/previous-statement)',
  })
  @IsOptional()
  @IsEnum(PREVIOUS_BALANCE_SOURCES)
  previousBalanceSource?:
    'STATEMENT' | 'PREVIOUS_VERIFICATION' | 'USER' | 'PREVIOUS_STATEMENT';

  @ApiPropertyOptional({
    default: false,
    description: "Also store mode as the card's rewardReporting setting",
  })
  @IsOptional()
  @IsBoolean()
  rememberForCard?: boolean;
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

  @ApiPropertyOptional({
    example: '26.35',
    description:
      'Legacy single rate applied to ANY foreign currency. Prefer exchangeRates.',
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
    example: { USD: '25.80', EUR: '28.10' },
    description:
      'Rate per foreign spend currency (ISO 4217 key). Value = units of the PRIMARY (card) currency per 1 unit of that currency (card HNL: USD "25.80" means 1 USD = 25.80 HNL). Merged over rates sent earlier.',
  })
  @IsOptional()
  @IsObject()
  exchangeRates?: Record<string, string>;

  @ApiPropertyOptional({
    example: '25.80',
    description:
      'Needed when the reward currency differs from the primary currency. Units of the PRIMARY (card) currency per 1 unit of the REWARD currency (card HNL, reward USD: "25.80").',
  })
  @IsOptional()
  @DecimalField({
    min: '0',
    max: '1000000',
    minInclusive: false,
    maxDecimals: 6,
  })
  rewardExchangeRate?: string;

  @ApiPropertyOptional({ example: 'CASH BAC CREDOMATIC' })
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  rewardProgramName?: string;

  @ApiPropertyOptional({
    type: RewardReportingDto,
    description:
      'How the bank reports the reward. Omit to keep the previous choice (or the card setting).',
  })
  @IsOptional()
  @ValidateNested()
  @Type(() => RewardReportingDto)
  rewardReporting?: RewardReportingDto;
}

export class PreviousStatementDto {
  @ApiPropertyOptional({
    example: 'CASH BAC CREDOMATIC',
    description:
      "Program to read when the verification's own program is ambiguous",
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

export class CategoriesFromSuggestionsDto {
  @ApiProperty({
    type: [String],
    example: ['Restaurantes y Comida rápida'],
    description:
      'Statement wordings to turn into categories (the `name` of `suggestedCategories[]`). Existing categories with the same name are reused.',
  })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(20)
  @Transform(({ value }: { value: unknown }) =>
    Array.isArray(value)
      ? value.map((v) => (typeof v === 'string' ? v.trim() : v))
      : value,
  )
  @IsString({ each: true })
  @IsNotEmpty({ each: true })
  @MaxLength(80, { each: true })
  names!: string[];
}

export class UpdateTransactionDto {
  @ApiProperty({
    nullable: true,
    description: 'Category of the line, or null to clear it',
  })
  @ValidateIf((_, value) => value !== null)
  @IsUUID()
  categoryId!: string | null;
}

export class TransactionIndexParam {
  @ApiProperty({ description: 'Verification id' })
  @IsUUID()
  id!: string;

  @ApiProperty({ minimum: 0 })
  @Type(() => Number)
  @IsInt()
  @Min(0)
  index!: number;
}

export class ListVerificationsQuery {
  @ApiPropertyOptional({
    enum: ['PROCESSING', 'AWAITING_RATES', 'COMPLETED', 'FAILED'],
  })
  @IsOptional()
  @IsEnum(['PROCESSING', 'AWAITING_RATES', 'COMPLETED', 'FAILED'])
  status?: 'PROCESSING' | 'AWAITING_RATES' | 'COMPLETED' | 'FAILED';

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
