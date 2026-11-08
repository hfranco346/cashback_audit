import Anthropic from '@anthropic-ai/sdk';
import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { CardsModule } from '../cards/cards.module.js';
import { CategoriesModule } from '../categories/categories.module.js';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module.js';
import type { Env } from '../config/env.js';
import { CleanupAwaitingRatesService } from './application/cleanup-awaiting-rates.service.js';
import { UpdateTransactionCategoryUseCase } from './application/update-transaction.use-case.js';
import { ConfirmVerificationUseCase } from './application/confirm-verification.use-case.js';
import { RateProposalService } from './application/rate-proposal.service.js';
import {
  CLASSIFICATION_MIN_CONFIDENCE,
  CreateVerificationUseCase,
} from './application/create-verification.use-case.js';
import {
  DeleteVerificationUseCase,
  GetVerificationUseCase,
  ListVerificationsUseCase,
} from './application/verification.use-cases.js';
import {
  LineClassifier,
  ResultExplainer,
  StatementExtractor,
} from './domain/statement-extractor.js';
import { VerificationRepository } from './domain/verification.repository.js';
import {
  ANTHROPIC_CLIENT,
  ClaudeJsonClient,
} from './infrastructure/claude/claude-json.client.js';
import { ClaudeResultExplainer } from './infrastructure/claude/claude-result-explainer.js';
import { ClaudeLineClassifier } from './infrastructure/claude/claude-line-classifier.js';
import { ClaudeStatementExtractor } from './infrastructure/claude/claude-statement-extractor.js';
import { PrismaVerificationRepository } from './infrastructure/prisma-verification.repository.js';
import { VerificationsController } from './infrastructure/verifications.controller.js';

@Module({
  imports: [CardsModule, CategoriesModule, SubscriptionsModule],
  controllers: [VerificationsController],
  providers: [
    CreateVerificationUseCase,
    ConfirmVerificationUseCase,
    RateProposalService,
    UpdateTransactionCategoryUseCase,
    CleanupAwaitingRatesService,
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
    { provide: LineClassifier, useClass: ClaudeLineClassifier },
    { provide: ResultExplainer, useClass: ClaudeResultExplainer },
    {
      provide: CLASSIFICATION_MIN_CONFIDENCE,
      inject: [ConfigService],
      useFactory: (config: ConfigService<Env, true>) =>
        config.get('CLASSIFICATION_MIN_CONFIDENCE', { infer: true }),
    },
    { provide: VerificationRepository, useClass: PrismaVerificationRepository },
  ],
})
export class VerificationsModule {}
