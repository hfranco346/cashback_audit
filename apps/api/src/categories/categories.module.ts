import { Module } from '@nestjs/common';
import { MerchantRepository } from '../merchants/domain/merchant.repository.js';
import {
  CreateMerchantUseCase,
  DeleteMerchantUseCase,
  GetMerchantUseCase,
  ListMerchantsUseCase,
  UpdateMerchantUseCase,
} from '../merchants/application/merchant.use-cases.js';
import { MerchantsController } from '../merchants/infrastructure/merchants.controller.js';
import { PrismaMerchantRepository } from '../merchants/infrastructure/prisma-merchant.repository.js';
import {
  CreateCategoryUseCase,
  DeleteCategoryUseCase,
  GetCategoryUseCase,
  ListCategoriesUseCase,
  UpdateCategoryUseCase,
} from './application/category.use-cases.js';
import { CategoryRepository } from './domain/category.repository.js';
import { CategoriesController } from './infrastructure/categories.controller.js';
import { PrismaCategoryRepository } from './infrastructure/prisma-category.repository.js';

/**
 * Categories and merchants are wired together: merchants must belong to a
 * category and categories report/reassign their merchants.
 */
@Module({
  controllers: [CategoriesController, MerchantsController],
  providers: [
    CreateCategoryUseCase,
    ListCategoriesUseCase,
    GetCategoryUseCase,
    UpdateCategoryUseCase,
    DeleteCategoryUseCase,
    CreateMerchantUseCase,
    ListMerchantsUseCase,
    GetMerchantUseCase,
    UpdateMerchantUseCase,
    DeleteMerchantUseCase,
    { provide: CategoryRepository, useClass: PrismaCategoryRepository },
    { provide: MerchantRepository, useClass: PrismaMerchantRepository },
  ],
  exports: [CategoryRepository, MerchantRepository],
})
export class CategoriesModule {}
