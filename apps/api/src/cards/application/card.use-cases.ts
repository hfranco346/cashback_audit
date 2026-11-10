import { Injectable } from '@nestjs/common';
import { Decimal } from 'decimal.js';
import { CategoryNotFoundError } from '../../categories/domain/category-errors.js';
import { CategoryRepository } from '../../categories/domain/category.repository.js';
import type {
  Card,
  RewardReportingSetting,
  RewardUnit,
} from '../domain/card.js';
import {
  CardNotFoundError,
  DuplicateRuleCategoryError,
} from '../domain/card-errors.js';
import { CardRepository, type CardPatch } from '../domain/card.repository.js';

export interface RuleInput {
  categoryId: string;
  ratePercent: string;
  monthlyCap?: string | null;
}

export interface CardInput {
  alias: string;
  bank: string;
  last4: string;
  network?: string | null;
  rewardUnit: RewardUnit;
  pointsPerCurrencyUnit?: string;
  baseRatePercent: string;
  currency: string;
  rewardProgramName?: string | null;
  rewardCurrency?: string | null;
  claimEmail?: string | null;
  rewardReporting?: RewardReportingSetting;
  rules?: RuleInput[];
}

@Injectable()
export class CardRulesValidator {
  constructor(private readonly categories: CategoryRepository) {}

  /** Rules must reference distinct categories owned by the user. */
  async toRules(userId: string, rules: RuleInput[]) {
    const seen = new Set<string>();
    for (const rule of rules) {
      if (seen.has(rule.categoryId))
        throw new DuplicateRuleCategoryError(rule.categoryId);
      seen.add(rule.categoryId);
    }
    const owned = await this.categories.findManyByIds(userId, [...seen]);
    if (owned.length !== seen.size) throw new CategoryNotFoundError();
    return rules.map((r) => ({
      categoryId: r.categoryId,
      ratePercent: new Decimal(r.ratePercent),
      monthlyCap: r.monthlyCap ? new Decimal(r.monthlyCap) : null,
    }));
  }
}

@Injectable()
export class CreateCardUseCase {
  constructor(
    private readonly cards: CardRepository,
    private readonly rules: CardRulesValidator,
  ) {}

  async execute(userId: string, input: CardInput): Promise<Card> {
    return this.cards.create({
      userId,
      alias: input.alias,
      bank: input.bank,
      last4: input.last4,
      network: input.network ?? null,
      rewardUnit: input.rewardUnit,
      pointsPerCurrencyUnit: new Decimal(input.pointsPerCurrencyUnit ?? '1'),
      baseRatePercent: new Decimal(input.baseRatePercent),
      currency: input.currency,
      rewardProgramName: input.rewardProgramName || null,
      rewardCurrency: input.rewardCurrency || null,
      claimEmail: input.claimEmail || null,
      rewardReporting: input.rewardReporting ?? 'AUTO',
      rules: await this.rules.toRules(userId, input.rules ?? []),
    });
  }
}

@Injectable()
export class ListCardsUseCase {
  constructor(private readonly cards: CardRepository) {}

  execute(userId: string): Promise<Card[]> {
    return this.cards.list(userId);
  }
}

@Injectable()
export class GetCardUseCase {
  constructor(private readonly cards: CardRepository) {}

  async execute(userId: string, id: string): Promise<Card> {
    const card = await this.cards.findById(userId, id);
    if (!card) throw new CardNotFoundError();
    return card;
  }
}

@Injectable()
export class UpdateCardUseCase {
  constructor(
    private readonly cards: CardRepository,
    private readonly rules: CardRulesValidator,
  ) {}

  async execute(
    userId: string,
    id: string,
    input: Partial<CardInput>,
  ): Promise<Card> {
    const patch: CardPatch = {};
    if (input.alias !== undefined) patch.alias = input.alias;
    if (input.bank !== undefined) patch.bank = input.bank;
    if (input.last4 !== undefined) patch.last4 = input.last4;
    if (input.network !== undefined) patch.network = input.network;
    if (input.rewardUnit !== undefined) patch.rewardUnit = input.rewardUnit;
    if (input.currency !== undefined) patch.currency = input.currency;
    if (input.rewardProgramName !== undefined) {
      patch.rewardProgramName = input.rewardProgramName || null;
    }
    if (input.rewardCurrency !== undefined) {
      patch.rewardCurrency = input.rewardCurrency || null;
    }
    if (input.claimEmail !== undefined) {
      patch.claimEmail = input.claimEmail || null;
    }
    if (input.rewardReporting !== undefined) {
      patch.rewardReporting = input.rewardReporting;
    }
    if (input.pointsPerCurrencyUnit !== undefined) {
      patch.pointsPerCurrencyUnit = new Decimal(input.pointsPerCurrencyUnit);
    }
    if (input.baseRatePercent !== undefined) {
      patch.baseRatePercent = new Decimal(input.baseRatePercent);
    }
    if (input.rules !== undefined) {
      patch.rules = await this.rules.toRules(userId, input.rules);
    }
    const updated = await this.cards.update(userId, id, patch);
    if (!updated) throw new CardNotFoundError();
    return updated;
  }
}

@Injectable()
export class DeleteCardUseCase {
  constructor(private readonly cards: CardRepository) {}

  async execute(userId: string, id: string): Promise<void> {
    if (!(await this.cards.delete(userId, id))) throw new CardNotFoundError();
  }
}
