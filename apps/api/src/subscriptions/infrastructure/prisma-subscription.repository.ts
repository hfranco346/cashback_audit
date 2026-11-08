import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma/prisma.service.js';
import { isUniqueViolation } from '../../shared/prisma/errors.js';
import type {
  RevenueCatEventInput,
  Subscription,
  SubscriptionTransition,
} from '../domain/subscription.js';
import {
  SubscriptionRepository,
  type ApplyOutcome,
} from '../domain/subscription.repository.js';

class DuplicateEvent extends Error {}

@Injectable()
export class PrismaSubscriptionRepository extends SubscriptionRepository {
  constructor(private readonly prisma: PrismaService) {
    super();
  }

  async find(
    userId: string,
    entitlementId: string,
  ): Promise<Subscription | null> {
    return this.prisma.subscription.findUnique({
      where: { userId_entitlementId: { userId, entitlementId } },
    });
  }

  async applyEvent(
    userId: string,
    entitlementId: string,
    event: RevenueCatEventInput,
    transition: SubscriptionTransition,
  ): Promise<ApplyOutcome> {
    try {
      return await this.prisma.$transaction(async (tx) => {
        try {
          await tx.revenueCatEvent.create({
            data: {
              id: event.id,
              type: event.type,
              userId,
              outcome: 'PENDING',
            },
          });
        } catch (error) {
          if (isUniqueViolation(error)) throw new DuplicateEvent();
          throw error;
        }
        const current = await tx.subscription.findUnique({
          where: { userId_entitlementId: { userId, entitlementId } },
        });
        if (
          current &&
          current.lastEventAt.getTime() > event.eventAt.getTime()
        ) {
          await tx.revenueCatEvent.update({
            where: { id: event.id },
            data: { outcome: 'STALE' },
          });
          return 'STALE' as const;
        }
        const data = {
          status: transition.status,
          willRenew: transition.willRenew,
          expiresAt: event.expirationAt,
          store: event.store ?? current?.store ?? null,
          productId: event.productId ?? current?.productId ?? null,
          rcAppUserId: event.appUserId,
          lastEventAt: event.eventAt,
        };
        await tx.subscription.upsert({
          where: { userId_entitlementId: { userId, entitlementId } },
          create: { userId, entitlementId, ...data },
          update: data,
        });
        await tx.revenueCatEvent.update({
          where: { id: event.id },
          data: { outcome: 'APPLIED' },
        });
        return 'APPLIED' as const;
      });
    } catch (error) {
      if (error instanceof DuplicateEvent) return 'DUPLICATE';
      throw error;
    }
  }

  async recordIgnored(
    event: RevenueCatEventInput,
    userId: string | null,
    reason: string,
  ): Promise<boolean> {
    try {
      await this.prisma.revenueCatEvent.create({
        data: {
          id: event.id,
          type: event.type,
          userId,
          outcome: `IGNORED:${reason}`,
        },
      });
      return true;
    } catch (error) {
      if (isUniqueViolation(error)) return false;
      throw error;
    }
  }
}
