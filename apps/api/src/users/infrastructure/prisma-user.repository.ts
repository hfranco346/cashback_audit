import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma/prisma.service.js';
import type { User as PrismaUser } from '../../shared/prisma/generated/client.js';
import type { User, VerifiedIdentity } from '../domain/user.js';
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
