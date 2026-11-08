import { Injectable } from '@nestjs/common';
import { CardRepository } from '../../cards/domain/card.repository.js';
import { CardNotFoundError } from '../../cards/domain/card-errors.js';
import type {
  Verification,
  VerificationStatus,
} from '../domain/verification.js';
import { VerificationNotFoundError } from '../domain/verification-errors.js';
import {
  VerificationRepository,
  type VerificationPage,
} from '../domain/verification.repository.js';

@Injectable()
export class ListVerificationsUseCase {
  constructor(
    private readonly verifications: VerificationRepository,
    private readonly cards: CardRepository,
  ) {}

  async execute(
    userId: string,
    options: {
      cardId?: string;
      status?: VerificationStatus;
      page: number;
      pageSize: number;
    },
  ): Promise<VerificationPage & { page: number; pageSize: number }> {
    if (
      options.cardId &&
      !(await this.cards.findById(userId, options.cardId))
    ) {
      throw new CardNotFoundError();
    }
    const result = await this.verifications.list(userId, {
      cardId: options.cardId,
      status: options.status,
      skip: (options.page - 1) * options.pageSize,
      take: options.pageSize,
    });
    return { ...result, page: options.page, pageSize: options.pageSize };
  }
}

@Injectable()
export class GetVerificationUseCase {
  constructor(private readonly verifications: VerificationRepository) {}

  async execute(userId: string, id: string): Promise<Verification> {
    const verification = await this.verifications.findById(userId, id);
    if (!verification) throw new VerificationNotFoundError();
    return verification;
  }
}

@Injectable()
export class DeleteVerificationUseCase {
  constructor(private readonly verifications: VerificationRepository) {}

  async execute(userId: string, id: string): Promise<void> {
    if (!(await this.verifications.delete(userId, id)))
      throw new VerificationNotFoundError();
  }
}
