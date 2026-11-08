import request from 'supertest';
import {
  createTestApp,
  resetDatabase,
  signInAs,
  type TestApp,
  type TestUser,
} from './test-app.js';

describe('Cards (e2e)', () => {
  let ctx: TestApp;
  let alice: TestUser;
  let bob: TestUser;
  const http = () => request(ctx.app.getHttpServer());

  beforeAll(async () => {
    ctx = await createTestApp();
  });
  afterAll(() => ctx.close());
  beforeEach(async () => {
    await resetDatabase(ctx.prisma);
    alice = await signInAs(ctx.app, 'alice');
    bob = await signInAs(ctx.app, 'bob');
  });

  const validCard = (extra: Record<string, unknown> = {}) => ({
    alias: 'Daily',
    bank: 'BBVA',
    last4: '4321',
    rewardUnit: 'CASHBACK_CURRENCY',
    baseRatePercent: 1,
    currency: 'mxn',
    ...extra,
  });
  const category = async (user: TestUser, name: string) =>
    (
      await http()
        .post('/api/v1/categories')
        .set(user.auth)
        .send({ name })
        .expect(201)
    ).body.id as string;

  it('requires authentication', async () => {
    await http().get('/api/v1/cards').expect(401);
  });

  it('creates a card with rules and serializes decimals as strings', async () => {
    const supermarkets = await category(alice, 'Supermarkets');
    const res = await http()
      .post('/api/v1/cards')
      .set(alice.auth)
      .send(
        validCard({
          network: 'VISA',
          baseRatePercent: '1.5',
          rules: [
            { categoryId: supermarkets, ratePercent: 5, monthlyCap: '500.50' },
          ],
        }),
      )
      .expect(201);
    expect(res.body).toMatchObject({
      alias: 'Daily',
      last4: '4321',
      network: 'VISA',
      rewardUnit: 'CASHBACK_CURRENCY',
      pointsPerCurrencyUnit: '1',
      baseRatePercent: '1.5',
      currency: 'MXN',
      rules: [
        { categoryId: supermarkets, ratePercent: '5', monthlyCap: '500.5' },
      ],
    });
  });

  it('stores rewardProgramName (null by default, clearable, trimmed)', async () => {
    const created = await http()
      .post('/api/v1/cards')
      .set(alice.auth)
      .send(validCard())
      .expect(201);
    expect(created.body.rewardProgramName).toBeNull();
    const set = await http()
      .patch(`/api/v1/cards/${created.body.id}`)
      .set(alice.auth)
      .send({ rewardProgramName: '  CASH BAC CREDOMATIC ' })
      .expect(200);
    expect(set.body.rewardProgramName).toBe('CASH BAC CREDOMATIC');
    const cleared = await http()
      .patch(`/api/v1/cards/${created.body.id}`)
      .set(alice.auth)
      .send({ rewardProgramName: null })
      .expect(200);
    expect(cleared.body.rewardProgramName).toBeNull();
    await http()
      .post('/api/v1/cards')
      .set(alice.auth)
      .send(validCard({ rewardProgramName: 'x'.repeat(81) }))
      .expect(400);
  });

  it.each([
    ['5 digits', { last4: '12345' }],
    ['a full PAN', { last4: '4111111111111111' }],
    ['3 digits', { last4: '123' }],
    ['non digits', { last4: '12ab' }],
  ])('rejects last4 with %s', async (_label, patch) => {
    const res = await http()
      .post('/api/v1/cards')
      .set(alice.auth)
      .send(validCard(patch))
      .expect(400);
    expect(res.body.code).toBe('VALIDATION_ERROR');
  });

  it('rejects unknown fields such as a full card number', async () => {
    await http()
      .post('/api/v1/cards')
      .set(alice.auth)
      .send(validCard({ pan: '4111111111111111' }))
      .expect(400);
  });

  it.each([
    ['bad currency', { currency: 'XXXX' }],
    ['rate over 100', { baseRatePercent: 101 }],
    ['negative rate', { baseRatePercent: -1 }],
    ['too many decimals', { baseRatePercent: '1.00001' }],
    ['bad reward unit', { rewardUnit: 'MILES' }],
    ['zero points ratio', { pointsPerCurrencyUnit: 0 }],
  ])('rejects %s', async (_label, patch) => {
    await http()
      .post('/api/v1/cards')
      .set(alice.auth)
      .send(validCard(patch))
      .expect(400);
  });

  it('rejects rules for categories the user does not own and duplicate rule categories', async () => {
    const bobCat = await category(bob, 'Bob');
    const mine = await category(alice, 'Mine');
    await http()
      .post('/api/v1/cards')
      .set(alice.auth)
      .send(validCard({ rules: [{ categoryId: bobCat, ratePercent: 5 }] }))
      .expect(404);
    const dup = await http()
      .post('/api/v1/cards')
      .set(alice.auth)
      .send(
        validCard({
          rules: [
            { categoryId: mine, ratePercent: 5 },
            { categoryId: mine, ratePercent: 3 },
          ],
        }),
      )
      .expect(400);
    expect(dup.body.code).toBe('DUPLICATE_RULE_CATEGORY');
  });

  it('isolates cards between users (404)', async () => {
    const card = (
      await http()
        .post('/api/v1/cards')
        .set(alice.auth)
        .send(validCard())
        .expect(201)
    ).body;
    await http().get(`/api/v1/cards/${card.id}`).set(bob.auth).expect(404);
    await http()
      .patch(`/api/v1/cards/${card.id}`)
      .set(bob.auth)
      .send({ alias: 'hack' })
      .expect(404);
    await http().delete(`/api/v1/cards/${card.id}`).set(bob.auth).expect(404);
    expect((await http().get('/api/v1/cards').set(bob.auth)).body).toEqual([]);
    expect(
      (await http().get(`/api/v1/cards/${card.id}`).set(alice.auth)).body.alias,
    ).toBe('Daily');
  });

  it('PATCH updates fields and replaces rules only when provided', async () => {
    const a = await category(alice, 'A');
    const b = await category(alice, 'B');
    const card = (
      await http()
        .post('/api/v1/cards')
        .set(alice.auth)
        .send(validCard({ rules: [{ categoryId: a, ratePercent: 5 }] }))
        .expect(201)
    ).body;

    const renamed = await http()
      .patch(`/api/v1/cards/${card.id}`)
      .set(alice.auth)
      .send({
        alias: 'Renamed',
        rewardUnit: 'POINTS',
        pointsPerCurrencyUnit: '2',
      })
      .expect(200);
    expect(renamed.body).toMatchObject({
      alias: 'Renamed',
      rewardUnit: 'POINTS',
      pointsPerCurrencyUnit: '2',
    });
    expect(renamed.body.rules).toHaveLength(1);

    const replaced = await http()
      .patch(`/api/v1/cards/${card.id}`)
      .set(alice.auth)
      .send({ rules: [{ categoryId: b, ratePercent: 3, monthlyCap: 100 }] })
      .expect(200);
    expect(replaced.body.rules).toEqual([
      { categoryId: b, ratePercent: '3', monthlyCap: '100' },
    ]);

    const cleared = await http()
      .patch(`/api/v1/cards/${card.id}`)
      .set(alice.auth)
      .send({ rules: [] })
      .expect(200);
    expect(cleared.body.rules).toEqual([]);
  });

  it('deletes a card', async () => {
    const card = (
      await http()
        .post('/api/v1/cards')
        .set(alice.auth)
        .send(validCard())
        .expect(201)
    ).body;
    await http().delete(`/api/v1/cards/${card.id}`).set(alice.auth).expect(204);
    await http().get(`/api/v1/cards/${card.id}`).set(alice.auth).expect(404);
  });

  it('rejects malformed ids with 400', async () => {
    await http().get('/api/v1/cards/not-a-uuid').set(alice.auth).expect(400);
  });
});
