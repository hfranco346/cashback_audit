import { Decimal } from 'decimal.js';
import { describe, expect, it } from 'vitest';
import {
  deriveEarned,
  labelSaysAccumulated,
  matchProgramName,
  shiftDate,
  suggestMode,
} from './reward-reporting.js';
import type { LoyaltyProgram } from './statement.js';

const d = (v: string | number) => new Decimal(v);
const prog = (over: Partial<LoyaltyProgram> = {}): LoyaltyProgram => ({
  name: 'CASH',
  accumulated: d(100),
  available: null,
  redeemedInPeriod: null,
  expiring: null,
  forfeited: null,
  previousBalance: null,
  earnedInPeriod: null,
  reportedLabel: null,
  unit: 'CURRENCY',
  currency: null,
  ...over,
});
const suggest = (
  program: LoyaltyProgram | null,
  over: Partial<Parameters<typeof suggestMode>[0]> = {},
) =>
  suggestMode({
    program,
    cardSetting: 'AUTO',
    expected: d(50),
    rewardUnit: 'CASHBACK_CURRENCY',
    ...over,
  });

describe('deriveEarned', () => {
  it('is current - previous + redeemed + expired', () => {
    expect(
      deriveEarned({
        currentBalance: d('200.50'),
        previousBalance: d(150),
        redeemedInPeriod: d(20),
        expiredInPeriod: d('4.25'),
      }).toString(),
    ).toBe('74.75');
  });

  it('keeps a negative result', () => {
    expect(
      deriveEarned({
        currentBalance: d(10),
        previousBalance: d(50),
        redeemedInPeriod: d(0),
        expiredInPeriod: d(0),
      }).toString(),
    ).toBe('-40');
  });
});

describe('suggestMode', () => {
  it('lets an explicit card setting win', () => {
    expect(
      suggest(prog({ previousBalance: d(1) }), { cardSetting: 'MONTHLY' }),
    ).toEqual({ suggestedMode: 'MONTHLY', reason: 'CARD_SETTING' });
    expect(suggest(prog(), { cardSetting: 'CUMULATIVE' })).toEqual({
      suggestedMode: 'CUMULATIVE',
      reason: 'CARD_SETTING',
    });
  });

  it('suggests CUMULATIVE when the statement prints a previous or earned figure', () => {
    expect(suggest(prog({ previousBalance: d(1) })).reason).toBe(
      'STATEMENT_HAS_PREVIOUS_BALANCE',
    );
    expect(suggest(prog({ earnedInPeriod: d(1) })).reason).toBe(
      'STATEMENT_HAS_PREVIOUS_BALANCE',
    );
  });

  it('reads the printed label', () => {
    expect(suggest(prog({ reportedLabel: 'Acumulado' }))).toEqual({
      suggestedMode: 'CUMULATIVE',
      reason: 'LABEL_SAYS_ACCUMULATED',
    });
    expect(labelSaysAccumulated('Bonificación del mes')).toBe(false);
    expect(labelSaysAccumulated('Saldo disponible')).toBe(true);
    expect(labelSaysAccumulated(null)).toBe(false);
  });

  it('flags a reported figure over 3x the expected one and over the floor', () => {
    expect(suggest(prog({ accumulated: d(151) })).reason).toBe(
      'REPORTED_FAR_ABOVE_EXPECTED',
    );
    expect(suggest(prog({ accumulated: d(150) })).reason).toBe('NONE');
    // tiny amounts never trigger it
    expect(
      suggest(prog({ accumulated: d(9) }), { expected: d(1) }).reason,
    ).toBe('NONE');
    // points use a larger floor
    expect(
      suggest(prog({ accumulated: d(400) }), {
        expected: d(10),
        rewardUnit: 'POINTS',
      }).reason,
    ).toBe('NONE');
    expect(
      suggest(prog({ accumulated: d(900) }), {
        expected: d(10),
        rewardUnit: 'POINTS',
      }).reason,
    ).toBe('REPORTED_FAR_ABOVE_EXPECTED');
  });

  it('is NONE without a program or an expected figure', () => {
    expect(suggest(null).reason).toBe('NONE');
    expect(suggest(prog(), { expected: null }).reason).toBe('NONE');
  });
});

describe('matchProgramName', () => {
  const names = [{ n: 'CASH BAC CREDOMATIC' }, { n: 'Puntos Viajero' }];
  const match = (wanted: string) => matchProgramName(names, (x) => x.n, wanted);

  it('matches ignoring case, accents and punctuation', () => {
    expect(match('cash bac  credomatic')?.n).toBe('CASH BAC CREDOMATIC');
    expect(match('PUNTOS VIAJERO.')?.n).toBe('Puntos Viajero');
  });

  it('falls back to a unique partial match only', () => {
    expect(match('Cash BAC')?.n).toBe('CASH BAC CREDOMATIC');
    expect(match('Millas')).toBeNull();
    expect(
      matchProgramName(
        [{ n: 'Puntos Plus' }, { n: 'Puntos Max' }],
        (x) => x.n,
        'Puntos',
      ),
    ).toBeNull();
  });
});

describe('shiftDate', () => {
  it('moves ISO dates across month and year bounds', () => {
    expect(shiftDate('2026-01-01', -5)).toBe('2025-12-27');
    expect(shiftDate('2026-02-26', 5)).toBe('2026-03-03');
  });
});
