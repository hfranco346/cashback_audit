import request from 'supertest';
import {
  createTestApp,
  resetDatabase,
  signInAs,
  type TestApp,
  type TestUser,
} from './test-app.js';

describe('User preferences (e2e)', () => {
  let ctx: TestApp;
  let alice: TestUser;
  let bob: TestUser;
  const http = () => request(ctx.app.getHttpServer());
  const me = async (user: TestUser) =>
    (await http().get('/api/v1/me').set(user.auth).expect(200)).body;
  const patch = (user: TestUser, body: Record<string, unknown>) =>
    http().patch('/api/v1/me/preferences').set(user.auth).send(body);

  beforeAll(async () => {
    ctx = await createTestApp();
  });
  afterAll(() => ctx.close());
  beforeEach(async () => {
    await resetDatabase(ctx.prisma);
    alice = await signInAs(ctx.app, 'alice');
    bob = await signInAs(ctx.app, 'bob');
  });

  it('requires authentication', async () => {
    await http().patch('/api/v1/me/preferences').send({}).expect(401);
  });

  it('GET /me starts with locale auto, no primary currency and no currencies', async () => {
    expect(await me(alice)).toMatchObject({
      id: alice.id,
      email: 'ana@example.com',
      locale: 'auto',
      primaryCurrency: null,
      currencies: [],
    });
  });

  it('updates the locale and the primary currency (case-insensitive input)', async () => {
    const res = await patch(alice, {
      locale: 'EN',
      primaryCurrency: 'hnl',
    }).expect(200);
    expect(res.body).toEqual({
      locale: 'en',
      primaryCurrency: 'HNL',
      currencies: [],
    });
    expect(await me(alice)).toMatchObject({
      locale: 'en',
      primaryCurrency: 'HNL',
    });
    // partial patches leave the rest alone; null clears the primary currency
    await patch(alice, { locale: 'es' }).expect(200);
    expect(await me(alice)).toMatchObject({
      locale: 'es',
      primaryCurrency: 'HNL',
    });
    await patch(alice, { primaryCurrency: null }).expect(200);
    expect((await me(alice)).primaryCurrency).toBeNull();
    await patch(alice, { locale: 'auto' }).expect(200);
    expect((await me(alice)).locale).toBe('auto');
  });

  it('stores the currency list with their last rates', async () => {
    const res = await patch(alice, {
      primaryCurrency: 'HNL',
      currencies: [
        { code: 'usd', lastRateToPrimary: '24.65' },
        { code: 'EUR' },
      ],
    }).expect(200);
    expect(
      res.body.currencies.map((c: any) => [c.code, c.lastRateToPrimary]),
    ).toEqual([
      ['EUR', null],
      ['USD', '24.65'],
    ]);
    expect(res.body.currencies[0].updatedAt).toEqual(expect.any(String));

    // omitted rate keeps the stored one; null clears; unlisted codes are removed
    const next = await patch(alice, {
      currencies: [{ code: 'USD' }, { code: 'GBP', lastRateToPrimary: 31.2 }],
    }).expect(200);
    expect(
      next.body.currencies.map((c: any) => [c.code, c.lastRateToPrimary]),
    ).toEqual([
      ['GBP', '31.2'],
      ['USD', '24.65'],
    ]);
    const cleared = await patch(alice, {
      currencies: [{ code: 'USD', lastRateToPrimary: null }],
    }).expect(200);
    expect(cleared.body.currencies).toHaveLength(1);
    expect(cleared.body.currencies[0].lastRateToPrimary).toBeNull();
    expect((await me(alice)).currencies).toHaveLength(1);
  });

  it('changing the primary currency clears the stored rates and drops the new primary from the list', async () => {
    await patch(alice, {
      primaryCurrency: 'HNL',
      currencies: [
        { code: 'USD', lastRateToPrimary: '24.65' },
        { code: 'EUR', lastRateToPrimary: '27' },
      ],
    }).expect(200);
    const res = await patch(alice, { primaryCurrency: 'USD' }).expect(200);
    expect(res.body.primaryCurrency).toBe('USD');
    expect(
      res.body.currencies.map((c: any) => [c.code, c.lastRateToPrimary]),
    ).toEqual([['EUR', null]]);
  });

  it('validates the input', async () => {
    await patch(alice, { locale: 'fr' }).expect(400);
    await patch(alice, { primaryCurrency: 'XX' }).expect(400);
    await patch(alice, { primaryCurrency: 'NOPE' }).expect(400);
    await patch(alice, { currencies: [{ code: 'ZZZ9' }] }).expect(400);
    await patch(alice, {
      currencies: [{ code: 'USD', lastRateToPrimary: '0' }],
    }).expect(400);
    await patch(alice, {
      currencies: [{ code: 'USD', lastRateToPrimary: 'abc' }],
    }).expect(400);
    await patch(alice, { unknownField: true }).expect(400);
    const dup = await patch(alice, {
      currencies: [{ code: 'USD' }, { code: 'usd' }],
    }).expect(400);
    expect(dup.body.code).toBe('INVALID_CURRENCIES');
    const self = await patch(alice, {
      primaryCurrency: 'HNL',
      currencies: [{ code: 'HNL' }],
    }).expect(400);
    expect(self.body.code).toBe('INVALID_CURRENCIES');
    // nothing was stored by the rejected requests
    expect(await me(alice)).toMatchObject({
      locale: 'auto',
      primaryCurrency: null,
      currencies: [],
    });
  });

  it("never touches another user's preferences", async () => {
    await patch(alice, {
      locale: 'en',
      primaryCurrency: 'HNL',
      currencies: [{ code: 'USD', lastRateToPrimary: '24' }],
    }).expect(200);
    expect(await me(bob)).toMatchObject({
      locale: 'auto',
      primaryCurrency: null,
      currencies: [],
    });
  });
});
