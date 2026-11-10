import { Decimal } from 'decimal.js';
import { normalizeText } from './merchant-matcher.js';
import type { LoyaltyProgram } from './statement.js';

export type ProgramSelectionSource = 'REQUEST' | 'CARD' | 'ONLY_PROGRAM';

export type ProgramSelection =
  | {
      status: 'SELECTED';
      program: LoyaltyProgram;
      source: ProgramSelectionSource;
    }
  | { status: 'NONE' }
  | { status: 'AMBIGUOUS'; names: string[]; requestedName: string | null };

/**
 * Picks the loyalty program to audit.
 * - A name (request first, then the card's `rewardProgramName`) selects the
 *   program whose name contains it (accent/case-insensitive); an exact match
 *   wins over a partial one.
 * - Without a name, a single program is used.
 * - Otherwise (several programs, or the name matches none/several) the caller
 *   must ask the user.
 */
export function selectLoyaltyProgram(
  programs: LoyaltyProgram[],
  requestedName: string | null | undefined,
  cardProgramName: string | null | undefined,
): ProgramSelection {
  if (programs.length === 0) return { status: 'NONE' };
  const names = programs.map((p) => p.name);

  const wanted = requestedName?.trim() ? requestedName : cardProgramName;
  const source: ProgramSelectionSource = requestedName?.trim()
    ? 'REQUEST'
    : 'CARD';
  const needle = wanted ? normalizeText(wanted) : '';

  if (needle) {
    const hits = programs.filter((p) => normalizeText(p.name).includes(needle));
    const exact = hits.filter((p) => normalizeText(p.name) === needle);
    const pick = exact.length === 1 ? exact : hits;
    if (pick.length === 1) {
      return { status: 'SELECTED', program: pick[0]!, source };
    }
    // A stale card setting must not block a statement with a single program.
    if (hits.length === 0 && source === 'CARD' && programs.length === 1) {
      return {
        status: 'SELECTED',
        program: programs[0]!,
        source: 'ONLY_PROGRAM',
      };
    }
    return { status: 'AMBIGUOUS', names, requestedName: wanted ?? null };
  }

  if (programs.length === 1) {
    return {
      status: 'SELECTED',
      program: programs[0]!,
      source: 'ONLY_PROGRAM',
    };
  }
  return { status: 'AMBIGUOUS', names, requestedName: null };
}

/**
 * Heuristic: the "accumulated" column looks like a running balance when it is
 * (about) available + redeemed + forfeited AND it is more than 3x the reward
 * expected for the period.
 */
export function looksCumulative(
  program: LoyaltyProgram,
  expected: Decimal,
): boolean {
  const { accumulated, available } = program;
  if (!accumulated || !available || accumulated.lte(0)) return false;
  const zero = new Decimal(0);
  const balance = available
    .plus(program.redeemedInPeriod ?? zero)
    .plus(program.forfeited ?? zero);
  const tolerance = Decimal.max(1, accumulated.abs().mul('0.01'));
  if (accumulated.minus(balance).abs().gt(tolerance)) return false;
  return accumulated.gt(expected.abs().mul(3));
}

export interface RewardProgramOption {
  name: string;
  unit: LoyaltyProgram['unit'];
  currency: string | null;
  reportedLabel: string | null;
}

/** Programs the user must choose from; only present while a choice is needed. */
export interface RewardProgramChoice {
  required: true;
  options: RewardProgramOption[];
}

/**
 * The user must pick a program only when the statement lists several and
 * neither the upload/earlier confirm name nor the card's program resolves one.
 * With a single program it is chosen automatically (no choice).
 */
export function proposeProgramChoice(
  programs: LoyaltyProgram[],
  requestedName: string | null | undefined,
  cardProgramName: string | null | undefined,
): RewardProgramChoice | null {
  if (programs.length < 2) return null;
  const selection = selectLoyaltyProgram(
    programs,
    requestedName,
    cardProgramName,
  );
  if (selection.status !== 'AMBIGUOUS') return null;
  return {
    required: true,
    options: programs.map((p) => ({
      name: p.name,
      unit: p.unit,
      currency: p.currency,
      reportedLabel: p.reportedLabel,
    })),
  };
}

/**
 * Resolves a program name sent by the user to exactly one of the statement's
 * programs (accent/case-insensitive; exact name wins over "contains").
 * Null when it matches none or several.
 */
export function matchProgramOption(
  programs: LoyaltyProgram[],
  name: string,
): LoyaltyProgram | null {
  const needle = normalizeText(name);
  if (!needle) return null;
  const hits = programs.filter((p) => normalizeText(p.name).includes(needle));
  const exact = hits.filter((p) => normalizeText(p.name) === needle);
  const pick = exact.length === 1 ? exact : hits;
  return pick.length === 1 ? pick[0]! : null;
}
