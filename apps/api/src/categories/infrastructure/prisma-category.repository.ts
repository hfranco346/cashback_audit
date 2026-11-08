import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma/prisma.service.js';
import { isUniqueViolation } from '../../shared/prisma/errors.js';
import type {
  Category,
  CategoryUsage,
  CategoryWithCount,
} from '../domain/category.js';
import { CategoryNameTakenError } from '../domain/category-errors.js';
import {
  CategoryRepository,
  type NewCategory,
} from '../domain/category.repository.js';

@Injectable()
export class PrismaCategoryRepository extends CategoryRepository {
  constructor(private readonly prisma: PrismaService) {
    super();
  }

  async create(input: NewCategory): Promise<Category> {
    try {
      return await this.prisma.merchantCategory.create({ data: input });
    } catch (error) {
      if (isUniqueViolation(error)) throw new CategoryNameTakenError();
      throw error;
    }
  }

  findById(userId: string, id: string): Promise<Category | null> {
    return this.prisma.merchantCategory.findFirst({ where: { id, userId } });
  }

  findManyByIds(userId: string, ids: string[]): Promise<Category[]> {
    return this.prisma.merchantCategory.findMany({
      where: { userId, id: { in: ids } },
    });
  }

  async listWithCounts(userId: string): Promise<CategoryWithCount[]> {
    const rows = await this.prisma.merchantCategory.findMany({
      where: { userId },
      orderBy: { name: 'asc' },
      include: { _count: { select: { merchants: true } } },
    });
    return rows.map(({ _count, ...category }) => ({
      ...category,
      merchantCount: _count.merchants,
    }));
  }

  async update(
    userId: string,
    id: string,
    patch: { name?: string; description?: string | null },
  ): Promise<Category | null> {
    try {
      const result = await this.prisma.merchantCategory.updateManyAndReturn({
        where: { id, userId },
        data: patch,
      });
      return result[0] ?? null;
    } catch (error) {
      if (isUniqueViolation(error)) throw new CategoryNameTakenError();
      throw error;
    }
  }

  async usage(userId: string, id: string): Promise<CategoryUsage> {
    const [merchants, cardRules] = await Promise.all([
      this.prisma.merchant.count({ where: { userId, categoryId: id } }),
      this.prisma.cardRule.count({
        where: { categoryId: id, card: { userId } },
      }),
    ]);
    return { merchants, cardRules };
  }

  async delete(
    userId: string,
    id: string,
    reassignTo: string | null,
  ): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      if (reassignTo) {
        await tx.merchant.updateMany({
          where: { userId, categoryId: id },
          data: { categoryId: reassignTo },
        });
        const rules = await tx.cardRule.findMany({ where: { categoryId: id } });
        for (const rule of rules) {
          const clash = await tx.cardRule.findUnique({
            where: {
              cardId_categoryId: {
                cardId: rule.cardId,
                categoryId: reassignTo,
              },
            },
          });
          if (clash) {
            await tx.cardRule.delete({ where: { id: rule.id } });
          } else {
            await tx.cardRule.update({
              where: { id: rule.id },
              data: { categoryId: reassignTo },
            });
          }
        }
      }
      await tx.merchantCategory.deleteMany({ where: { id, userId } });
    });
  }
}
