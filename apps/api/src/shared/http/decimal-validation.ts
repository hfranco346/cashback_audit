import { applyDecorators } from '@nestjs/common';
import { Transform } from 'class-transformer';
import { ValidationOptions, registerDecorator } from 'class-validator';
import { Decimal } from 'decimal.js';

export interface DecimalRange {
  min: string;
  max: string;
  /** Allow the lower bound itself (default true). */
  minInclusive?: boolean;
  maxDecimals: number;
}

/**
 * Accepts a JSON number or a numeric string and normalizes it to a string, so
 * values are never subject to binary floating point rounding.
 */
const toDecimalString = ({ value }: { value: unknown }) =>
  typeof value === 'number' && Number.isFinite(value) ? String(value) : value;

function IsDecimalInRange(
  range: DecimalRange,
  options?: ValidationOptions,
): PropertyDecorator {
  return (target: object, propertyName: string | symbol) => {
    registerDecorator({
      name: 'isDecimalInRange',
      target: target.constructor,
      propertyName: propertyName as string,
      options: {
        message: `${String(propertyName)} must be a decimal between ${range.min} and ${range.max} with at most ${range.maxDecimals} decimals`,
        ...options,
      },
      validator: {
        validate(value: unknown) {
          if (typeof value !== 'string' || !/^\d+(\.\d+)?$/.test(value))
            return false;
          const decimals = value.split('.')[1]?.length ?? 0;
          if (decimals > range.maxDecimals) return false;
          const d = new Decimal(value);
          if (d.gt(range.max)) return false;
          return range.minInclusive === false
            ? d.gt(range.min)
            : d.gte(range.min);
        },
      },
    });
  };
}

/** Decimal request field: number or string in, validated string out. */
export const DecimalField = (range: DecimalRange) =>
  applyDecorators(Transform(toDecimalString), IsDecimalInRange(range));
