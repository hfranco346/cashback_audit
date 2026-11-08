import type { User, VerifiedIdentity } from './user.js';

export abstract class UserRepository {
  /**
   * Creates the user on first sign-in. Afterwards the email is refreshed when
   * present and the name is stored only if the user has none yet (Apple sends
   * the name once, so a later sign-in must never erase it).
   */
  abstract upsertFromIdentity(identity: VerifiedIdentity): Promise<User>;
  abstract findById(id: string): Promise<User | null>;
}
