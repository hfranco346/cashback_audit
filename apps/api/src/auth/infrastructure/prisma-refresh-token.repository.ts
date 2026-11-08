import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma/prisma.service.js';
import {
  RefreshTokenRepository,
  type NewRefreshToken,
  type RefreshTokenRecord,
} from '../domain/refresh-token.repository.js';

@Injectable()
export class PrismaRefreshTokenRepository extends RefreshTokenRepository {
  constructor(private readonly prisma: PrismaService) {
    super();
  }

  async create(record: NewRefreshToken): Promise<void> {
    await this.prisma.refreshToken.create({ data: record });
  }

  async findByHash(tokenHash: string): Promise<RefreshTokenRecord | null> {
    return this.prisma.refreshToken.findUnique({ where: { tokenHash } });
  }

  async rotate(oldId: string, next: NewRefreshToken): Promise<boolean> {
    return this.prisma.$transaction(async (tx) => {
      const revoked = await tx.refreshToken.updateMany({
        where: { id: oldId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      if (revoked.count !== 1) return false;
      await tx.refreshToken.create({ data: next });
      return true;
    });
  }

  async revokeFamily(familyId: string): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: { familyId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }
}
