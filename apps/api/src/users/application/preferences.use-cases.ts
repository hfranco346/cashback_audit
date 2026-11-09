import { Injectable } from '@nestjs/common';
import { DomainError } from '../../shared/domain/domain-error.js';
import type {
  PreferencesPatch,
  UserPreferences,
} from '../domain/preferences.js';
import { UserRepository } from '../domain/user.repository.js';

const unknownUser = () =>
  new DomainError('UNAUTHENTICATED', 'UNAUTHORIZED', 'Unknown user');

@Injectable()
export class GetPreferencesUseCase {
  constructor(private readonly users: UserRepository) {}

  async execute(userId: string): Promise<UserPreferences> {
    const prefs = await this.users.getPreferences(userId);
    if (!prefs) throw unknownUser();
    return prefs;
  }
}

@Injectable()
export class UpdatePreferencesUseCase {
  constructor(private readonly users: UserRepository) {}

  async execute(
    userId: string,
    patch: PreferencesPatch,
  ): Promise<UserPreferences> {
    const current = await this.users.getPreferences(userId);
    if (!current) throw unknownUser();
    if (patch.currencies) {
      const primary =
        patch.primaryCurrency === undefined
          ? current.primaryCurrency
          : patch.primaryCurrency;
      const codes = patch.currencies.map((c) => c.code);
      if (new Set(codes).size !== codes.length) {
        throw new DomainError(
          'VALIDATION',
          'INVALID_CURRENCIES',
          'currencies must not repeat a currency code',
        );
      }
      if (primary && codes.includes(primary)) {
        throw new DomainError(
          'VALIDATION',
          'INVALID_CURRENCIES',
          `currencies must not include the primary currency (${primary})`,
        );
      }
    }
    const updated = await this.users.updatePreferences(userId, patch);
    if (!updated) throw unknownUser();
    return updated;
  }
}
