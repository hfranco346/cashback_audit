import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsISO4217CurrencyCode,
  IsOptional,
  ValidateNested,
} from 'class-validator';
import { DecimalField } from '../../shared/http/decimal-validation.js';

const upper = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim().toUpperCase() : value;
const lower = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim().toLowerCase() : value;
const upperOrNull = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim().toUpperCase() || null : value;

/** Same bounds as the exchange rates sent when confirming a verification. */
const RATE = {
  min: '0',
  max: '1000000000',
  minInclusive: false,
  maxDecimals: 6,
} as const;

export const LOCALES = ['auto', 'es', 'en'] as const;
export type LocaleValue = (typeof LOCALES)[number];

export class CurrencyPreferenceDto {
  @ApiProperty({ example: 'USD' })
  @Transform(upper)
  @IsISO4217CurrencyCode()
  code!: string;

  @ApiPropertyOptional({
    example: '24.65',
    nullable: true,
    description:
      'Primary-currency units per 1 unit of this currency. Omit to keep the stored rate; null clears it.',
  })
  @IsOptional()
  @DecimalField(RATE)
  lastRateToPrimary?: string | null;
}

export class UpdatePreferencesDto {
  @ApiPropertyOptional({ enum: LOCALES })
  @IsOptional()
  @Transform(lower)
  @IsEnum(LOCALES)
  locale?: LocaleValue;

  @ApiPropertyOptional({ example: 'HNL', nullable: true })
  @IsOptional()
  @Transform(upperOrNull)
  @IsISO4217CurrencyCode()
  primaryCurrency?: string | null;

  @ApiPropertyOptional({
    type: [CurrencyPreferenceDto],
    description: 'The complete list; currencies not listed are removed.',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(30)
  @ValidateNested({ each: true })
  @Type(() => CurrencyPreferenceDto)
  currencies?: CurrencyPreferenceDto[];
}
