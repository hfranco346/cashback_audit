import { Module } from '@nestjs/common';
import { GetMeUseCase } from './application/get-me.use-case.js';
import { UserRepository } from './domain/user.repository.js';
import { MeController } from './infrastructure/me.controller.js';
import { PrismaUserRepository } from './infrastructure/prisma-user.repository.js';

@Module({
  controllers: [MeController],
  providers: [
    GetMeUseCase,
    { provide: UserRepository, useClass: PrismaUserRepository },
  ],
  exports: [UserRepository],
})
export class UsersModule {}
