import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { AuthenticatedUser } from '../../auth/domain/authenticated-user.js';
import { CurrentUser } from '../../auth/infrastructure/current-user.decorator.js';
import { IdParam } from '../../shared/http/id.param.js';
import {
  CreateCardUseCase,
  DeleteCardUseCase,
  GetCardUseCase,
  ListCardsUseCase,
  UpdateCardUseCase,
} from '../application/card.use-cases.js';
import type { Card } from '../domain/card.js';
import { CreateCardDto, UpdateCardDto } from './card.dto.js';

/** Decimals are serialized as strings (e.g. "1.5") to avoid float rounding. */
export const presentCard = (card: Card) => ({
  id: card.id,
  alias: card.alias,
  bank: card.bank,
  last4: card.last4,
  network: card.network,
  rewardUnit: card.rewardUnit,
  pointsPerCurrencyUnit: card.pointsPerCurrencyUnit.toString(),
  baseRatePercent: card.baseRatePercent.toString(),
  currency: card.currency,
  rewardProgramName: card.rewardProgramName,
  rewardCurrency: card.rewardCurrency,
  claimEmail: card.claimEmail,
  rules: card.rules.map((r) => ({
    categoryId: r.categoryId,
    ratePercent: r.ratePercent.toString(),
    monthlyCap: r.monthlyCap?.toString() ?? null,
  })),
  createdAt: card.createdAt.toISOString(),
  updatedAt: card.updatedAt.toISOString(),
});

@ApiTags('cards')
@ApiBearerAuth()
@Controller('cards')
export class CardsController {
  constructor(
    private readonly createCard: CreateCardUseCase,
    private readonly listCards: ListCardsUseCase,
    private readonly getCard: GetCardUseCase,
    private readonly updateCard: UpdateCardUseCase,
    private readonly deleteCard: DeleteCardUseCase,
  ) {}

  @Post()
  async create(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateCardDto,
  ) {
    return presentCard(await this.createCard.execute(user.id, dto));
  }

  @Get()
  async list(@CurrentUser() user: AuthenticatedUser) {
    return (await this.listCards.execute(user.id)).map(presentCard);
  }

  @Get(':id')
  async get(@CurrentUser() user: AuthenticatedUser, @Param() { id }: IdParam) {
    return presentCard(await this.getCard.execute(user.id, id));
  }

  @Patch(':id')
  async update(
    @CurrentUser() user: AuthenticatedUser,
    @Param() { id }: IdParam,
    @Body() dto: UpdateCardDto,
  ) {
    return presentCard(await this.updateCard.execute(user.id, id, dto));
  }

  @Delete(':id')
  @HttpCode(204)
  async remove(
    @CurrentUser() user: AuthenticatedUser,
    @Param() { id }: IdParam,
  ): Promise<void> {
    await this.deleteCard.execute(user.id, id);
  }
}
