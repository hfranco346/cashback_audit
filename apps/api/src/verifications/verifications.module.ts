import Anthropic from '@anthropic-ai/sdk';
import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { CardsModule } from '../cards/cards.module.js';
import { CategoriesModule } from '../categories/categories.module.js';
import type { Env } from '../config/env.js';
import { CreateVerificationUseCase } from './application/create-verification.use-case.js';
import {
  DeleteVerificationUseCase,
  GetVerificationUseCase,
  ListVerificationsUseCase,
} from './application/verification.use-cases.js';
import {
  MerchantClassifier,
  StatementExtractor,
} from './domain/statement-extractor.js';
import { VerificationRepository } from './domain/verification.repository.js';
import {
  ANTHROPIC_CLIENT,
  ClaudeJsonClient,
} from './infrastructure/claude/claude-json.client.js';
import { ClaudeMerchantClassifier } from './infrastructure/claude/claude-merchant-classifier.js';
import { ClaudeStatementExtractor } from './infrastructure/claude/claude-statement-extractor.js';
import { PrismaVerificationRepository } from './infrastructure/prisma-verification.repository.js';
import { VerificationsController } from './infrastructure/verifications.controller.js';

@Module({
  imports: [CardsModule, CategoriesModule],
  controllers: [VerificationsController],
  providers: [
    CreateVerificationUseCase,
    ListVerificationsUseCase,
    GetVerificationUseCase,
    DeleteVerificationUseCase,
    ClaudeJsonClient,
    {
      provide: ANTHROPIC_CLIENT,
      inject: [ConfigService],
      useFactory: (config: ConfigService<Env, true>) =>
        new Anthropic({
          // An empty key is reported as "unavailable" at call time, not at boot.
          apiKey:
            config.get('ANTHROPIC_API_KEY', { infer: true }) ||
            'not-configured',
          timeout: 4 * 60 * 1000,
          maxRetries: 2,
        }),
    },
    { provide: StatementExtractor, useClass: ClaudeStatementExtractor },
    { provide: MerchantClassifier, useClass: ClaudeMerchantClassifier },
    { provide: VerificationRepository, useClass: PrismaVerificationRepository },
  ],
})
export class VerificationsModule {}
