export type AuthProviderName = 'GOOGLE' | 'APPLE' | 'EMAIL';

export interface User {
  id: string;
  provider: AuthProviderName;
  providerSubject: string;
  email: string | null;
  name: string | null;
  /** Operator-set; no API endpoint can change it. */
  unlimitedCredits: boolean;
  createdAt: Date;
}

/** Facts extracted from a verified Google/Apple identity token. */
export interface VerifiedIdentity {
  provider: AuthProviderName;
  subject: string;
  email: string | null;
  /** Google puts it in the token; Apple only sends it on first sign-in. */
  name: string | null;
}
