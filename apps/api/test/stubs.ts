import { InvalidIdentityTokenError } from '../src/auth/domain/auth-errors.js';
import type { VerifiedIdentity } from '../src/users/domain/user.js';

/** Accepts `google-ok:<subject>`; anything else is rejected. */
export const googleStub = {
  verify: async (token: string): Promise<VerifiedIdentity> => {
    if (!token.startsWith('google-ok:')) throw new InvalidIdentityTokenError();
    return {
      provider: 'GOOGLE',
      subject: token.slice('google-ok:'.length),
      email: 'ana@example.com',
      name: 'Ana Google',
    };
  },
};

/** Accepts `apple-ok:<subject>`; the client-sent full name is the name. */
export const appleStub = {
  verify: async (
    token: string,
    fullName?: string,
  ): Promise<VerifiedIdentity> => {
    if (!token.startsWith('apple-ok:')) throw new InvalidIdentityTokenError();
    return {
      provider: 'APPLE',
      subject: token.slice('apple-ok:'.length),
      email: 'relay@privaterelay.appleid.com',
      name: fullName?.trim() || null,
    };
  },
};
