import request from 'supertest';
import { createTestApp, type TestApp } from './test-app.js';

describe('Health (e2e)', () => {
  let ctx: TestApp;

  beforeAll(async () => {
    ctx = await createTestApp();
  });

  afterAll(async () => {
    await ctx.close();
  });

  it('GET /api/v1/health reports ok with database up', async () => {
    const res = await request(ctx.app.getHttpServer())
      .get('/api/v1/health')
      .expect(200);
    expect(res.body).toMatchObject({ status: 'ok', database: 'up' });
  });

  it('applies security headers', async () => {
    const res = await request(ctx.app.getHttpServer()).get('/api/v1/health');
    expect(res.headers['x-content-type-options']).toBe('nosniff');
  });
});
