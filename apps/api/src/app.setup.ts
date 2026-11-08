import { INestApplication, ValidationPipe } from '@nestjs/common';
import helmet from 'helmet';

export const API_PREFIX = 'api/v1';

/** Shared by `main.ts` and the e2e tests so both run the same pipeline. */
export function configureApp(app: INestApplication): void {
  app.setGlobalPrefix(API_PREFIX);
  app.use(helmet());
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );
}
