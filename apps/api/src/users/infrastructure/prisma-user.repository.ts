import { Injectable } from '@nestjs/common';
import { Decimal } from 'decimal.js';
import { PrismaService } from '../../shared/prisma/prisma.service.js';
import type { User as PrismaUser } from '../../shared/prisma/generated/client.js';
import type { User, VerifiedIdentity } from '../domain/user.js';
import type {
  PreferencesPatch,
  UserPreferences,
} from '../domain/preferences.js';
import { UserRepository } from '../domain/user.repository.js';

@Injectable()
export class PrismaUserRepository extends UserRepository {
  constructor(private readonly prisma: PrismaService) {
    super();
  }

  async upsertFromIdentity(identity: VerifiedIdentity): Promise<User> {
    const where = {
      provider_providerSubject: {
        provider: identity.provider,
        providerSubject: identity.subject,
      },
    };
    const user = await this.prisma.user.upsert({
      where,
      create: {
        provider: identity.provider,
        providerSubject: identity.subject,
        email: identity.email,
        name: identity.name,
      },
      update: identity.email ? { email: identity.email } : {},
    });
    if (identity.name && !user.name) {
      const updated = await this.prisma.user.update({
        where: { id: user.id },
        data: { name: identity.name },
      });
      return this.toDomain(updated);
    }
    return this.toDomain(user);
  }

  async findById(id: string): Promise<User | null> {
    const user = await this.prisma.user.findUnique({ where: { id } });
    return user ? this.toDomain(user) : null;
  }

  async getPreferences(userId: string): Promise<UserPreferences | null> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { currencies: { orderBy: { code: 'asc' } } },
    });
    return user ? this.toPreferences(user) : null;
  }

  async updatePreferences(
    userId: string,
    patch: PreferencesPatch,
  ): Promise<UserPreferences | null> {
    return this.prisma.$transaction(async (tx) => {
      const current = await tx.user.findUnique({ where: { id: userId } });
      if (!current) return null;
      const primary =
        patch.primaryCurrency === undefined
          ? current.primaryCurrency
          : patch.primaryCurrency;
      await tx.user.update({
        where: { id: userId },
        data: {
          ...(patch.locale && { locale: patch.locale }),
          ...(patch.primaryCurrency !== undefined && {
            primaryCurrency: patch.primaryCurrency,
          }),
        },
      });
      if (primary !== current.primaryCurrency) {
        await tx.userCurrency.updateMany({
          where: { userId },
          data: { lastRateToPrimary: null },
        });
        if (primary)
          await tx.userCurrency.deleteMany({
            where: { userId, code: primary },
          });
      }
      if (patch.currencies) {
        const codes = patch.currencies.map((c) => c.code);
        await tx.userCurrency.deleteMany({
          where: { userId, code: { notIn: codes } },
        });
        for (const c of patch.currencies) {
          const rate = c.lastRateToPrimary;
          await tx.userCurrency.upsert({
            where: { userId_code: { userId, code: c.code } },
            create: {
              userId,
              code: c.code,
              lastRateToPrimary: rate ? rate.toString() : null,
            },
            update:
              rate === undefined
                ? {}
                : { lastRateToPrimary: rate ? rate.toString() : null },
          });
        }
      }
      const fresh = await tx.user.findUniqueOrThrow({
        where: { id: userId },
        include: { currencies: { orderBy: { code: 'asc' } } },
      });
      return this.toPreferences(fresh);
    });
  }

  async recordCurrencyRates(
    userId: string,
    cardCurrency: string,
    rates: { code: string; rate: Decimal }[],
  ): Promise<void> {
    const wanted = rates.filter((r) => r.code !== cardCurrency);
    if (wanted.length === 0) return;
    await this.prisma.$transaction(async (tx) => {
      const user = await tx.user.findUnique({ where: { id: userId } });
      if (!user) return;
      if (user.primaryCurrency && user.primaryCurrency !== cardCurrency) return;
      for (const { code, rate } of wanted) {
        await tx.userCurrency.upsert({
          where: { userId_code: { userId, code } },
          create: { userId, code, lastRateToPrimary: rate.toString() },
          update: { lastRateToPrimary: rate.toString() },
        });
      }
    });
  }

  private toPreferences(
    row: PrismaUser & {
      currencies: {
        code: string;
        lastRateToPrimary: { toString(): string } | null;
        updatedAt: Date;
      }[];
    },
  ): UserPreferences {
    return {
      locale: row.locale,
      primaryCurrency: row.primaryCurrency,
      currencies: row.currencies.map((c) => ({
        code: c.code,
        lastRateToPrimary: c.lastRateToPrimary
          ? new Decimal(c.lastRateToPrimary.toString())
          : null,
        updatedAt: c.updatedAt,
      })),
    };
  }

  private toDomain(row: PrismaUser): User {
    return {
      id: row.id,
      provider: row.provider,
      providerSubject: row.providerSubject,
      email: row.email,
      name: row.name,
      createdAt: row.createdAt,
    };
  }
}
