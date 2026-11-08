import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaPg } from '@prisma/adapter-pg';
import type { Env } from '../../config/env.js';
import { PrismaClient } from './generated/client.js';

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  constructor(config: ConfigService<Env, true>) {
    const url = new URL(config.get('DATABASE_URL', { infer: true }));
    const schema = url.searchParams.get('schema') ?? undefined;
    url.searchParams.delete('schema');
    super({
      adapter: new PrismaPg(
        { connectionString: url.toString() },
        schema ? { schema } : undefined,
      ),
    });
  }

  async onModuleInit(): Promise<void> {
    await this.$connect();
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }
}
