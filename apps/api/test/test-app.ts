import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import {
  AppleIdTokenVerifier,
  GoogleIdTokenVerifier,
} from '../src/auth/domain/identity-token-verifier.js';
import { appleStub, googleStub } from './stubs.js';
import { AppModule } from '../src/app.module.js';
import { configureApp } from '../src/app.setup.js';
import { PrismaService } from '../src/shared/prisma/prisma.service.js';

export interface TestApp {
  app: INestApplication;
  prisma: PrismaService;
  close: () => Promise<void>;
}

export type Override = { token: unknown; useValue: unknown };

export async function createTestApp(
  overrides: Override[] = [],
): Promise<TestApp> {
  let builder = Test.createTestingModule({ imports: [AppModule] });
  const all: Override[] = [
    { token: GoogleIdTokenVerifier, useValue: googleStub },
    { token: AppleIdTokenVerifier, useValue: appleStub },
    ...overrides,
  ];
  for (const { token, useValue } of all) {
    builder = builder.overrideProvider(token).useValue(useValue);
  }
  const moduleRef = await builder.compile();
  const app = moduleRef.createNestApplication();
  configureApp(app);
  await app.init();
  const prisma = app.get(PrismaService);
  return { app, prisma, close: () => app.close() };
}

/** Removes all rows so each test starts from a clean database. */
export async function resetDatabase(prisma: PrismaService): Promise<void> {
  const tables = await prisma.$queryRaw<{ tablename: string }[]>`
    SELECT tablename FROM pg_tables
    WHERE schemaname = current_schema() AND tablename <> '_prisma_migrations'`;
  if (tables.length === 0) return;
  const list = tables.map((t) => `"${t.tablename}"`).join(', ');
  await prisma.$executeRawUnsafe(
    `TRUNCATE TABLE ${list} RESTART IDENTITY CASCADE`,
  );
}

export interface TestUser {
  id: string;
  accessToken: string;
  auth: { Authorization: string };
}

/** Signs in through the (stubbed) Google endpoint and returns bearer headers. */
export async function signInAs(
  app: INestApplication,
  subject: string,
): Promise<TestUser> {
  const res = await request(app.getHttpServer())
    .post('/api/v1/auth/google')
    .send({ idToken: `google-ok:${subject}` })
    .expect(200);
  return {
    id: res.body.user.id,
    accessToken: res.body.accessToken,
    auth: { Authorization: `Bearer ${res.body.accessToken}` },
  };
}
