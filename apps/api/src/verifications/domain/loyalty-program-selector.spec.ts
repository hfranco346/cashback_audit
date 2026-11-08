import { Decimal } from 'decimal.js';
import {
  looksCumulative,
  selectLoyaltyProgram,
} from './loyalty-program-selector.js';
import type { LoyaltyProgram } from './statement.js';

const d = (v: string | number) => new Decimal(v);
const program = (
  name: string,
  over: Partial<LoyaltyProgram> = {},
): LoyaltyProgram => ({
  name,
  accumulated: d(10),
  available: null,
  redeemedInPeriod: null,
  expiring: null,
  forfeited: null,
  unit: 'POINTS',
  currency: null,
  ...over,
});

const points = program('PUNTOS BAC CREDOMATIC');
const cash = program('CASH BAC CREDOMATIC', { unit: 'CURRENCY' });

describe('selectLoyaltyProgram', () => {
  it('returns NONE without programs', () => {
    expect(selectLoyaltyProgram([], null, null)).toEqual({ status: 'NONE' });
  });

  it('uses the only program when no name is set', () => {
    expect(selectLoyaltyProgram([cash], null, null)).toEqual({
      status: 'SELECTED',
      program: cash,
      source: 'ONLY_PROGRAM',
    });
  });

  it('is ambiguous with several programs and no name', () => {
    expect(selectLoyaltyProgram([points, cash], null, null)).toEqual({
      status: 'AMBIGUOUS',
      names: ['PUNTOS BAC CREDOMATIC', 'CASH BAC CREDOMATIC'],
      requestedName: null,
    });
  });

  it('matches the card program name case/accent-insensitively by contains', () => {
    const result = selectLoyaltyProgram([points, cash], null, 'cásh bac');
    expect(result).toMatchObject({
      status: 'SELECTED',
      program: cash,
      source: 'CARD',
    });
  });

  it('lets the request name win over the card name', () => {
    const result = selectLoyaltyProgram([points, cash], 'puntos', 'cash');
    expect(result).toMatchObject({
      status: 'SELECTED',
      program: points,
      source: 'REQUEST',
    });
  });

  it('prefers an exact match over a partial one', () => {
    const plain = program('CASH');
    const result = selectLoyaltyProgram(
      [program('CASH PLUS'), plain],
      'cash',
      null,
    );
    expect(result).toMatchObject({ status: 'SELECTED', program: plain });
  });

  it('is ambiguous when the name matches several programs', () => {
    const result = selectLoyaltyProgram([points, cash], 'bac credomatic', null);
    expect(result).toMatchObject({
      status: 'AMBIGUOUS',
      requestedName: 'bac credomatic',
    });
  });

  it('is ambiguous when a requested name matches nothing', () => {
    expect(selectLoyaltyProgram([points], 'miles', null)).toMatchObject({
      status: 'AMBIGUOUS',
      names: ['PUNTOS BAC CREDOMATIC'],
    });
  });

  it('ignores a stale card name when the statement has a single program', () => {
    expect(selectLoyaltyProgram([points], null, 'old program')).toMatchObject({
      status: 'SELECTED',
      program: points,
      source: 'ONLY_PROGRAM',
    });
  });

  it('is ambiguous for a stale card name with several programs', () => {
    expect(
      selectLoyaltyProgram([points, cash], null, 'old program'),
    ).toMatchObject({ status: 'AMBIGUOUS' });
  });
});

describe('looksCumulative', () => {
  const running = program('X', {
    accumulated: d(1000),
    available: d(900),
    redeemedInPeriod: d(60),
    forfeited: d(40),
  });

  it('flags accumulated = available + redeemed + forfeited well above expected', () => {
    expect(looksCumulative(running, d(100))).toBe(true);
  });

  it('does not flag when accumulated is within 3x of the expected reward', () => {
    expect(looksCumulative(running, d(334))).toBe(false);
    expect(looksCumulative(running, d(333))).toBe(true);
  });

  it('does not flag when the columns do not add up', () => {
    expect(looksCumulative({ ...running, available: d(100) }, d(10))).toBe(
      false,
    );
  });

  it('needs the available column', () => {
    expect(looksCumulative({ ...running, available: null }, d(10))).toBe(false);
  });

  it('treats missing redeemed/forfeited as zero', () => {
    expect(
      looksCumulative(
        program('X', { accumulated: d(500), available: d(500) }),
        d(10),
      ),
    ).toBe(true);
  });

  it('ignores zero accumulated', () => {
    expect(
      looksCumulative(
        program('X', { accumulated: d(0), available: d(0) }),
        d(0),
      ),
    ).toBe(false);
  });
});
