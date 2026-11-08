import { Module } from '@nestjs/common';
import { CategoriesModule } from '../categories/categories.module.js';
import {
  CardRulesValidator,
  CreateCardUseCase,
  DeleteCardUseCase,
  GetCardUseCase,
  ListCardsUseCase,
  UpdateCardUseCase,
} from './application/card.use-cases.js';
import { CardRepository } from './domain/card.repository.js';
import { CardsController } from './infrastructure/cards.controller.js';
import { PrismaCardRepository } from './infrastructure/prisma-card.repository.js';

@Module({
  imports: [CategoriesModule],
  controllers: [CardsController],
  providers: [
    CardRulesValidator,
    CreateCardUseCase,
    ListCardsUseCase,
    GetCardUseCase,
    UpdateCardUseCase,
    DeleteCardUseCase,
    { provide: CardRepository, useClass: PrismaCardRepository },
  ],
  exports: [CardRepository],
})
export class CardsModule {}
