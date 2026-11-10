import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma/prisma.service.js';
import {
  EmailLoginCodeRepository,
  type EmailLoginCodeRecord,
} from '../domain/email-login-code.repository.js';

@Injectable()
export class PrismaEmailLoginCodeRepository extends EmailLoginCodeRepository {
  constructor(private readonly prisma: PrismaService) {
    super();
  }

  async findActive(email: string): Promise<EmailLoginCodeRecord | null> {
    return this.prisma.emailLoginCode.findFirst({
      where: { email, consumedAt: null },
      orderBy: { createdAt: 'desc' },
    });
  }

  async createdSince(email: string, since: Date): Promise<Date[]> {
    const rows = await this.prisma.emailLoginCode.findMany({
      where: { email, createdAt: { gt: since } },
      orderBy: { createdAt: 'asc' },
      select: { createdAt: true },
    });
    return rows.map((r) => r.createdAt);
  }

  async lastCreatedAt(email: string): Promise<Date | null> {
    const row = await this.prisma.emailLoginCode.findFirst({
      where: { email },
      orderBy: { createdAt: 'desc' },
      select: { createdAt: true },
    });
    return row?.createdAt ?? null;
  }

  async replaceActive(data: {
    email: string;
    codeHash: string;
    expiresAt: Date;
    ip: string | null;
  }): Promise<EmailLoginCodeRecord> {
    const [, created] = await this.prisma.$transaction([
      this.prisma.emailLoginCode.updateMany({
        where: { email: data.email, consumedAt: null },
        data: { consumedAt: new Date() },
      }),
      this.prisma.emailLoginCode.create({ data }),
    ]);
    return created;
  }

  async claimAttempt(id: string, maxAttempts: number): Promise<number | null> {
    const rows = await this.prisma.$queryRaw<{ attempts: number }[]>`
      UPDATE "EmailLoginCode" SET "attempts" = "attempts" + 1
      WHERE "id" = ${id}::uuid AND "consumedAt" IS NULL AND "attempts" < ${maxAttempts}
      RETURNING "attempts"`;
    return rows[0]?.attempts ?? null;
  }

  async consume(id: string): Promise<boolean> {
    const { count } = await this.prisma.emailLoginCode.updateMany({
      where: { id, consumedAt: null },
      data: { consumedAt: new Date() },
    });
    return count === 1;
  }

  async deleteCreatedBefore(date: Date): Promise<number> {
    const { count } = await this.prisma.emailLoginCode.deleteMany({
      where: { createdAt: { lt: date } },
    });
    return count;
  }

  async delete(id: string): Promise<void> {
    await this.prisma.emailLoginCode.deleteMany({ where: { id } });
  }
}
