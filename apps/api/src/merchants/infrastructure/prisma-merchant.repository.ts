import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma/prisma.service.js';
import { isUniqueViolation } from '../../shared/prisma/errors.js';
import type { Merchant } from '../domain/merchant.js';
import { MerchantNameTakenError } from '../domain/merchant-errors.js';
import {
  MerchantRepository,
  type NewMerchant,
} from '../domain/merchant.repository.js';

@Injectable()
export class PrismaMerchantRepository extends MerchantRepository {
  constructor(private readonly prisma: PrismaService) {
    super();
  }

  async create(input: NewMerchant): Promise<Merchant> {
    try {
      return await this.prisma.merchant.create({ data: input });
    } catch (error) {
      if (isUniqueViolation(error)) throw new MerchantNameTakenError();
      throw error;
    }
  }

  findById(userId: string, id: string): Promise<Merchant | null> {
    return this.prisma.merchant.findFirst({ where: { id, userId } });
  }

  list(userId: string, filter: { categoryId?: string }): Promise<Merchant[]> {
    return this.prisma.merchant.findMany({
      where: {
        userId,
        ...(filter.categoryId && { categoryId: filter.categoryId }),
      },
      orderBy: { name: 'asc' },
    });
  }

  async update(
    userId: string,
    id: string,
    patch: Partial<Pick<NewMerchant, 'name' | 'keywords' | 'categoryId'>>,
  ): Promise<Merchant | null> {
    try {
      const result = await this.prisma.merchant.updateManyAndReturn({
        where: { id, userId },
        data: patch,
      });
      return result[0] ?? null;
    } catch (error) {
      if (isUniqueViolation(error)) throw new MerchantNameTakenError();
      throw error;
    }
  }

  async delete(userId: string, id: string): Promise<boolean> {
    const result = await this.prisma.merchant.deleteMany({
      where: { id, userId },
    });
    return result.count > 0;
  }
}
