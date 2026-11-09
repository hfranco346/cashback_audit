import { Injectable } from '@nestjs/common';
import { Decimal } from 'decimal.js';
import { PrismaService } from '../../shared/prisma/prisma.service.js';
import type {
  Card as PrismaCard,
  CardRule as PrismaRule,
} from '../../shared/prisma/generated/client.js';
import type { Card, CardRule } from '../domain/card.js';
import {
  CardRepository,
  type CardPatch,
  type NewCard,
} from '../domain/card.repository.js';

type Row = PrismaCard & { rules: PrismaRule[] };

const dec = (value: { toString(): string }) => new Decimal(value.toString());

export function toDomainCard(row: Row): Card {
  return {
    id: row.id,
    userId: row.userId,
    alias: row.alias,
    bank: row.bank,
    last4: row.last4,
    network: row.network,
    rewardUnit: row.rewardUnit,
    pointsPerCurrencyUnit: dec(row.pointsPerCurrencyUnit),
    baseRatePercent: dec(row.baseRatePercent),
    currency: row.currency,
    rewardProgramName: row.rewardProgramName,
    rewardCurrency: row.rewardCurrency,
    rules: row.rules.map((r) => ({
      categoryId: r.categoryId,
      ratePercent: dec(r.ratePercent),
      monthlyCap: r.monthlyCap ? dec(r.monthlyCap) : null,
    })),
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  };
}

const ruleData = (r: CardRule) => ({
  categoryId: r.categoryId,
  ratePercent: r.ratePercent.toString(),
  monthlyCap: r.monthlyCap?.toString() ?? null,
});

@Injectable()
export class PrismaCardRepository extends CardRepository {
  constructor(private readonly prisma: PrismaService) {
    super();
  }

  async create(input: NewCard): Promise<Card> {
    const { rules, ...card } = input;
    const row = await this.prisma.card.create({
      data: {
        ...card,
        pointsPerCurrencyUnit: card.pointsPerCurrencyUnit.toString(),
        baseRatePercent: card.baseRatePercent.toString(),
        rules: { create: rules.map(ruleData) },
      },
      include: { rules: { orderBy: { id: 'asc' } } },
    });
    return toDomainCard(row);
  }

  async findById(userId: string, id: string): Promise<Card | null> {
    const row = await this.prisma.card.findFirst({
      where: { id, userId, deletedAt: null },
      include: { rules: { orderBy: { id: 'asc' } } },
    });
    return row ? toDomainCard(row) : null;
  }

  async list(userId: string): Promise<Card[]> {
    const rows = await this.prisma.card.findMany({
      where: { userId, deletedAt: null },
      orderBy: { createdAt: 'asc' },
      include: { rules: { orderBy: { id: 'asc' } } },
    });
    return rows.map(toDomainCard);
  }

  async update(
    userId: string,
    id: string,
    patch: CardPatch,
  ): Promise<Card | null> {
    const { rules, pointsPerCurrencyUnit, baseRatePercent, ...rest } = patch;
    return this.prisma.$transaction(async (tx) => {
      const owned = await tx.card.findFirst({
        where: { id, userId, deletedAt: null },
        select: { id: true },
      });
      if (!owned) return null;
      const row = await tx.card.update({
        where: { id },
        data: {
          ...rest,
          ...(pointsPerCurrencyUnit && {
            pointsPerCurrencyUnit: pointsPerCurrencyUnit.toString(),
          }),
          ...(baseRatePercent && {
            baseRatePercent: baseRatePercent.toString(),
          }),
          ...(rules && {
            rules: { deleteMany: {}, create: rules.map(ruleData) },
          }),
        },
        include: { rules: { orderBy: { id: 'asc' } } },
      });
      return toDomainCard(row);
    });
  }

  async delete(userId: string, id: string): Promise<boolean> {
    const result = await this.prisma.card.updateMany({
      where: { id, userId, deletedAt: null },
      data: { deletedAt: new Date() },
    });
    return result.count > 0;
  }
}
