import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { AuthenticatedUser } from '../../auth/domain/authenticated-user.js';
import { CurrentUser } from '../../auth/infrastructure/current-user.decorator.js';
import { IdParam } from '../../shared/http/id.param.js';
import {
  CreateMerchantUseCase,
  DeleteMerchantUseCase,
  GetMerchantUseCase,
  ListMerchantsUseCase,
  UpdateMerchantUseCase,
} from '../application/merchant.use-cases.js';
import {
  CreateMerchantDto,
  ListMerchantsQuery,
  UpdateMerchantDto,
} from './merchant.dto.js';
import { presentMerchant } from './merchant.presenter.js';

@ApiTags('merchants')
@ApiBearerAuth()
@Controller('merchants')
export class MerchantsController {
  constructor(
    private readonly createMerchant: CreateMerchantUseCase,
    private readonly listMerchants: ListMerchantsUseCase,
    private readonly getMerchant: GetMerchantUseCase,
    private readonly updateMerchant: UpdateMerchantUseCase,
    private readonly deleteMerchant: DeleteMerchantUseCase,
  ) {}

  @Post()
  async create(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateMerchantDto,
  ) {
    return presentMerchant(
      await this.createMerchant.execute({
        userId: user.id,
        name: dto.name,
        keywords: dto.keywords,
        categoryId: dto.categoryId,
      }),
    );
  }

  @Get()
  async list(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: ListMerchantsQuery,
  ) {
    return (await this.listMerchants.execute(user.id, query)).map(
      presentMerchant,
    );
  }

  @Get(':id')
  async get(@CurrentUser() user: AuthenticatedUser, @Param() { id }: IdParam) {
    return presentMerchant(await this.getMerchant.execute(user.id, id));
  }

  @Patch(':id')
  async update(
    @CurrentUser() user: AuthenticatedUser,
    @Param() { id }: IdParam,
    @Body() dto: UpdateMerchantDto,
  ) {
    return presentMerchant(await this.updateMerchant.execute(user.id, id, dto));
  }

  @Delete(':id')
  @HttpCode(204)
  async remove(
    @CurrentUser() user: AuthenticatedUser,
    @Param() { id }: IdParam,
  ): Promise<void> {
    await this.deleteMerchant.execute(user.id, id);
  }
}
