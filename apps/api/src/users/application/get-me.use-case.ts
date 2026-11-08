import { Injectable } from '@nestjs/common';
import { DomainError } from '../../shared/domain/domain-error.js';
import type { User } from '../domain/user.js';
import { UserRepository } from '../domain/user.repository.js';

@Injectable()
export class GetMeUseCase {
  constructor(private readonly users: UserRepository) {}

  async execute(userId: string): Promise<User> {
    const user = await this.users.findById(userId);
    if (!user) {
      // The access token outlived the account.
      throw new DomainError('UNAUTHENTICATED', 'UNAUTHORIZED', 'Unknown user');
    }
    return user;
  }
}
