import {
  parseArgs,
  setUnlimitedCredits,
  type UnlimitedCreditsStore,
} from './set-unlimited-credits.js';

function fakeStore(users: { id: string; email: string }[]) {
  const flags = new Map<string, boolean>();
  const store: UnlimitedCreditsStore = {
    findUserIdsByEmail: async (email) =>
      users.filter((u) => u.email.toLowerCase() === email).map((u) => u.id),
    setUnlimited: async (ids, value) => {
      for (const id of ids) flags.set(id, value);
    },
  };
  return { store, flags };
}

describe('setUnlimitedCredits', () => {
  const users = [
    { id: 'g', email: 'Owner@Example.com' },
    { id: 'e', email: 'owner@example.com' },
    { id: 'x', email: 'other@example.com' },
  ];

  it('flags every provider account of the (normalized) email', async () => {
    const { store, flags } = fakeStore(users);
    const ids = await setUnlimitedCredits(store, '  OWNER@example.com ', true);
    expect(ids).toEqual(['g', 'e']);
    expect(Object.fromEntries(flags)).toEqual({ g: true, e: true });
  });

  it('turns it off', async () => {
    const { store, flags } = fakeStore(users);
    await setUnlimitedCredits(store, 'owner@example.com', false);
    expect(flags.get('g')).toBe(false);
  });

  it('returns no ids and writes nothing when nobody matches', async () => {
    const { store, flags } = fakeStore(users);
    expect(
      await setUnlimitedCredits(store, 'nobody@example.com', true),
    ).toEqual([]);
    expect(flags.size).toBe(0);
  });
});

describe('parseArgs', () => {
  it('defaults to on and lowercases', () => {
    expect(parseArgs([' A@B.com '])).toEqual({
      ok: true,
      email: 'a@b.com',
      value: true,
    });
  });
  it('accepts off', () => {
    expect(parseArgs(['a@b.com', 'off'])).toMatchObject({ value: false });
  });
  it('rejects missing email, bad mode and extra args', () => {
    expect(parseArgs([]).ok).toBe(false);
    expect(parseArgs(['nope']).ok).toBe(false);
    expect(parseArgs(['a@b.com', 'maybe']).ok).toBe(false);
    expect(parseArgs(['a@b.com', 'on', 'x']).ok).toBe(false);
  });
});
