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
import { presentMerchant } from '../../merchants/infrastructure/merchant.presenter.js';
import {
  CreateCategoryUseCase,
  DeleteCategoryUseCase,
  GetCategoryUseCase,
  ListCategoriesUseCase,
  UpdateCategoryUseCase,
  type CategoryDetail,
} from '../application/category.use-cases.js';
import type { Category } from '../domain/category.js';
import {
  CreateCategoryDto,
  DeleteCategoryQuery,
  ListCategoriesQuery,
  UpdateCategoryDto,
} from './category.dto.js';

const present = (c: Category | CategoryDetail) => ({
  id: c.id,
  name: c.name,
  description: c.description,
  ...('merchantCount' in c && { merchantCount: c.merchantCount }),
  ...('merchants' in c &&
    c.merchants && { merchants: c.merchants.map(presentMerchant) }),
  createdAt: c.createdAt.toISOString(),
  updatedAt: c.updatedAt.toISOString(),
});

@ApiTags('categories')
@ApiBearerAuth()
@Controller('categories')
export class CategoriesController {
  constructor(
    private readonly createCategory: CreateCategoryUseCase,
    private readonly listCategories: ListCategoriesUseCase,
    private readonly getCategory: GetCategoryUseCase,
    private readonly updateCategory: UpdateCategoryUseCase,
    private readonly deleteCategory: DeleteCategoryUseCase,
  ) {}

  @Post()
  async create(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateCategoryDto,
  ) {
    const created = await this.createCategory.execute({
      userId: user.id,
      name: dto.name,
      description: dto.description,
    });
    return present({ ...created, merchantCount: 0 });
  }

  @Get()
  async list(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: ListCategoriesQuery,
  ) {
    return (
      await this.listCategories.execute(
        user.id,
        query.includeMerchants ?? false,
      )
    ).map(present);
  }

  @Get(':id')
  async get(@CurrentUser() user: AuthenticatedUser, @Param() { id }: IdParam) {
    return present(await this.getCategory.execute(user.id, id));
  }

  @Patch(':id')
  async update(
    @CurrentUser() user: AuthenticatedUser,
    @Param() { id }: IdParam,
    @Body() dto: UpdateCategoryDto,
  ) {
    return present(await this.updateCategory.execute(user.id, id, dto));
  }

  @Delete(':id')
  @HttpCode(204)
  async remove(
    @CurrentUser() user: AuthenticatedUser,
    @Param() { id }: IdParam,
    @Query() query: DeleteCategoryQuery,
  ): Promise<void> {
    await this.deleteCategory.execute(user.id, id, query.reassignTo);
  }
}
