import request from 'supertest';
import {
  createTestApp,
  resetDatabase,
  signInAs,
  type TestApp,
  type TestUser,
} from './test-app.js';

describe('Categories & merchants (e2e)', () => {
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

  const createCategory = async (user: TestUser, name: string) =>
    (
      await http()
        .post('/api/v1/categories')
        .set(user.auth)
        .send({ name })
        .expect(201)
    ).body;
  const createMerchant = async (
    user: TestUser,
    name: string,
    categoryId: string,
    keywords: string[] = [],
  ) =>
    (
      await http()
        .post('/api/v1/merchants')
        .set(user.auth)
        .send({ name, categoryId, keywords })
        .expect(201)
    ).body;

  it('requires authentication', async () => {
    await http().get('/api/v1/categories').expect(401);
    await http().get('/api/v1/merchants').expect(401);
  });

  it('creates, lists, updates and deletes a category', async () => {
    const created = await createCategory(alice, 'Supermarkets');
    expect(created).toMatchObject({
      name: 'Supermarkets',
      description: null,
      merchantCount: 0,
    });

    const updated = await http()
      .patch(`/api/v1/categories/${created.id}`)
      .set(alice.auth)
      .send({ description: 'Groceries' })
      .expect(200);
    expect(updated.body.description).toBe('Groceries');

    const list = await http()
      .get('/api/v1/categories')
      .set(alice.auth)
      .expect(200);
    expect(list.body).toHaveLength(1);
    expect(list.body[0].merchants).toBeUndefined();

    await http()
      .delete(`/api/v1/categories/${created.id}`)
      .set(alice.auth)
      .expect(204);
    await http()
      .get(`/api/v1/categories/${created.id}`)
      .set(alice.auth)
      .expect(404);
  });

  it('rejects duplicate category names per user but allows them across users', async () => {
    await createCategory(alice, 'Gas');
    const dup = await http()
      .post('/api/v1/categories')
      .set(alice.auth)
      .send({ name: 'Gas' })
      .expect(409);
    expect(dup.body.code).toBe('CATEGORY_NAME_TAKEN');
    await http()
      .post('/api/v1/categories')
      .set(bob.auth)
      .send({ name: 'Gas' })
      .expect(201);
  });

  it('isolates categories between users (404, never 403)', async () => {
    const cat = await createCategory(alice, 'Private');
    await http().get(`/api/v1/categories/${cat.id}`).set(bob.auth).expect(404);
    await http()
      .patch(`/api/v1/categories/${cat.id}`)
      .set(bob.auth)
      .send({ name: 'x' })
      .expect(404);
    await http()
      .delete(`/api/v1/categories/${cat.id}`)
      .set(bob.auth)
      .expect(404);
    expect((await http().get('/api/v1/categories').set(bob.auth)).body).toEqual(
      [],
    );
  });

  it('creates merchants with keywords and reports merchantCount / includeMerchants', async () => {
    const cat = await createCategory(alice, 'Supermarkets');
    const walmart = await createMerchant(alice, 'Walmart', cat.id, [
      'WAL MART',
      ' wal mart ',
      'WALMART SUC',
    ]);
    expect(walmart.keywords).toEqual(['WAL MART', 'WALMART SUC']);
    await createMerchant(alice, 'Soriana', cat.id);

    const list = await http()
      .get('/api/v1/categories?includeMerchants=true')
      .set(alice.auth)
      .expect(200);
    expect(list.body[0].merchantCount).toBe(2);
    expect(list.body[0].merchants.map((m: { name: string }) => m.name)).toEqual(
      ['Soriana', 'Walmart'],
    );

    const detail = await http()
      .get(`/api/v1/categories/${cat.id}`)
      .set(alice.auth)
      .expect(200);
    expect(detail.body.merchants).toHaveLength(2);
  });

  it("refuses merchants in another user's category and isolates merchants", async () => {
    const bobCat = await createCategory(bob, 'Bob stuff');
    const res = await http()
      .post('/api/v1/merchants')
      .set(alice.auth)
      .send({ name: 'Walmart', categoryId: bobCat.id })
      .expect(404);
    expect(res.body.code).toBe('CATEGORY_NOT_FOUND');

    const aliceCat = await createCategory(alice, 'Mine');
    const merchant = await createMerchant(alice, 'Walmart', aliceCat.id);
    await http()
      .get(`/api/v1/merchants/${merchant.id}`)
      .set(bob.auth)
      .expect(404);
    await http()
      .delete(`/api/v1/merchants/${merchant.id}`)
      .set(bob.auth)
      .expect(404);
  });

  it('PATCH /merchants/:id reassigns the category (only to own categories)', async () => {
    const a = await createCategory(alice, 'A');
    const b = await createCategory(alice, 'B');
    const bobCat = await createCategory(bob, 'C');
    const m = await createMerchant(alice, 'Shop', a.id);

    const moved = await http()
      .patch(`/api/v1/merchants/${m.id}`)
      .set(alice.auth)
      .send({ categoryId: b.id })
      .expect(200);
    expect(moved.body.categoryId).toBe(b.id);
    await http()
      .patch(`/api/v1/merchants/${m.id}`)
      .set(alice.auth)
      .send({ categoryId: bobCat.id })
      .expect(404);
    expect(
      (await http().get(`/api/v1/merchants?categoryId=${b.id}`).set(alice.auth))
        .body,
    ).toHaveLength(1);
    expect(
      (await http().get(`/api/v1/merchants?categoryId=${a.id}`).set(alice.auth))
        .body,
    ).toHaveLength(0);
  });

  it('rejects duplicate merchant names per user', async () => {
    const cat = await createCategory(alice, 'A');
    await createMerchant(alice, 'Walmart', cat.id);
    const dup = await http()
      .post('/api/v1/merchants')
      .set(alice.auth)
      .send({ name: 'Walmart', categoryId: cat.id })
      .expect(409);
    expect(dup.body.code).toBe('MERCHANT_NAME_TAKEN');
  });

  describe('deleting a category with merchants', () => {
    it('returns 409 CATEGORY_IN_USE without reassignTo', async () => {
      const cat = await createCategory(alice, 'Supermarkets');
      await createMerchant(alice, 'Walmart', cat.id);
      const res = await http()
        .delete(`/api/v1/categories/${cat.id}`)
        .set(alice.auth)
        .expect(409);
      expect(res.body).toMatchObject({
        code: 'CATEGORY_IN_USE',
        details: { merchants: 1, cardRules: 0 },
      });
    });

    it('moves merchants and card rules with ?reassignTo', async () => {
      const from = await createCategory(alice, 'Old');
      const to = await createCategory(alice, 'New');
      const m = await createMerchant(alice, 'Walmart', from.id);
      const card = await http()
        .post('/api/v1/cards')
        .set(alice.auth)
        .send({
          alias: 'c',
          bank: 'b',
          last4: '1234',
          rewardUnit: 'CASHBACK_CURRENCY',
          baseRatePercent: 1,
          currency: 'MXN',
          rules: [{ categoryId: from.id, ratePercent: 5 }],
        })
        .expect(201);

      await http()
        .delete(`/api/v1/categories/${from.id}?reassignTo=${to.id}`)
        .set(alice.auth)
        .expect(204);

      expect(
        (await http().get(`/api/v1/merchants/${m.id}`).set(alice.auth)).body
          .categoryId,
      ).toBe(to.id);
      const reloaded = await http()
        .get(`/api/v1/cards/${card.body.id}`)
        .set(alice.auth);
      expect(reloaded.body.rules).toEqual([
        { categoryId: to.id, ratePercent: '5', monthlyCap: null },
      ]);
    });

    it('404s when reassignTo is missing, foreign, or the category itself', async () => {
      const cat = await createCategory(alice, 'A');
      const bobCat = await createCategory(bob, 'B');
      await createMerchant(alice, 'Walmart', cat.id);
      await http()
        .delete(`/api/v1/categories/${cat.id}?reassignTo=${bobCat.id}`)
        .set(alice.auth)
        .expect(404);
      await http()
        .delete(`/api/v1/categories/${cat.id}?reassignTo=${cat.id}`)
        .set(alice.auth)
        .expect(404);
      await http()
        .delete(`/api/v1/categories/${cat.id}?reassignTo=not-a-uuid`)
        .set(alice.auth)
        .expect(400);
    });
  });
});
