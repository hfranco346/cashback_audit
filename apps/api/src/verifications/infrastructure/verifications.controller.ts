import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Post,
  Query,
  UnsupportedMediaTypeException,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiBody, ApiConsumes, ApiTags } from '@nestjs/swagger';
import { memoryStorage } from 'multer';
import type { AuthenticatedUser } from '../../auth/domain/authenticated-user.js';
import { CurrentUser } from '../../auth/infrastructure/current-user.decorator.js';
import { IdParam } from '../../shared/http/id.param.js';
import { StrictThrottle } from '../../shared/http/throttling.js';
import { SubscriptionGuard } from '../../subscriptions/infrastructure/subscription.guard.js';
import { ConfirmVerificationUseCase } from '../application/confirm-verification.use-case.js';
import { RateProposalService } from '../application/rate-proposal.service.js';
import { CreateVerificationUseCase } from '../application/create-verification.use-case.js';
import {
  DeleteVerificationUseCase,
  GetVerificationUseCase,
  ListVerificationsUseCase,
} from '../application/verification.use-cases.js';
import {
  ConfirmVerificationDto,
  CreateVerificationDto,
  ListVerificationsQuery,
} from './verification.dto.js';
import {
  presentSummary,
  presentVerification,
} from './verification.presenter.js';

export const MAX_PDF_BYTES = 10 * 1024 * 1024;

/** Multer options: the PDF lives in memory only and is never written to disk. */
export const pdfUploadOptions = {
  storage: memoryStorage(),
  limits: { fileSize: MAX_PDF_BYTES, files: 1, fields: 8 },
  fileFilter: (
    _req: unknown,
    file: { mimetype: string },
    callback: (error: Error | null, accept: boolean) => void,
  ) => {
    if (file.mimetype !== 'application/pdf') {
      callback(
        new UnsupportedMediaTypeException({
          code: 'UNSUPPORTED_MEDIA_TYPE',
          message: 'Only PDF files are accepted',
        }),
        false,
      );
      return;
    }
    callback(null, true);
  },
};

@ApiTags('verifications')
@ApiBearerAuth()
@Controller('verifications')
export class VerificationsController {
  constructor(
    private readonly createVerification: CreateVerificationUseCase,
    private readonly confirmVerification: ConfirmVerificationUseCase,
    private readonly proposals: RateProposalService,
    private readonly listVerifications: ListVerificationsUseCase,
    private readonly getVerification: GetVerificationUseCase,
    private readonly deleteVerification: DeleteVerificationUseCase,
  ) {}

  @Post()
  @UseGuards(SubscriptionGuard)
  @StrictThrottle()
  @UseInterceptors(FileInterceptor('file', pdfUploadOptions))
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['file', 'cardId'],
      properties: {
        file: {
          type: 'string',
          format: 'binary',
          description: 'Statement PDF (max 10 MB)',
        },
        cardId: { type: 'string', format: 'uuid' },
        exchangeRate: { type: 'string', example: '24.65' },
        rewardProgramName: { type: 'string', example: 'CASH BAC CREDOMATIC' },
      },
    },
  })
  async create(
    @CurrentUser() user: AuthenticatedUser,
    @UploadedFile() file: { buffer: Buffer } | undefined,
    @Body() dto: CreateVerificationDto,
  ) {
    if (!file?.buffer?.length) {
      throw new BadRequestException({
        code: 'FILE_REQUIRED',
        message: 'A PDF file is required in the "file" field',
      });
    }
    const verification = await this.createVerification.execute({
      userId: user.id,
      cardId: dto.cardId,
      pdf: file.buffer,
      exchangeRate: dto.exchangeRate,
      rewardProgramName: dto.rewardProgramName,
    });
    return presentVerification(
      verification,
      await this.proposals.forVerification(user.id, verification),
    );
  }

  @Post(':id/confirm')
  @HttpCode(200)
  async confirm(
    @CurrentUser() user: AuthenticatedUser,
    @Param() { id }: IdParam,
    @Body() dto: ConfirmVerificationDto,
  ) {
    const verification = await this.confirmVerification.execute({
      userId: user.id,
      verificationId: id,
      baseRatePercent: dto.baseRatePercent,
      categoryRates: dto.categoryRates,
      saveToCard: dto.saveToCard,
      reportedRewardOverride: dto.reportedRewardOverride,
      exchangeRate: dto.exchangeRate,
      rewardProgramName: dto.rewardProgramName,
    });
    return presentVerification(
      verification,
      await this.proposals.forVerification(user.id, verification),
    );
  }

  @Get()
  async list(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: ListVerificationsQuery,
  ) {
    const result = await this.listVerifications.execute(user.id, {
      cardId: query.cardId,
      status: query.status,
      page: query.page,
      pageSize: query.pageSize,
    });
    return {
      items: result.items.map(presentSummary),
      page: result.page,
      pageSize: result.pageSize,
      total: result.total,
    };
  }

  @Get(':id')
  async get(@CurrentUser() user: AuthenticatedUser, @Param() { id }: IdParam) {
    const verification = await this.getVerification.execute(user.id, id);
    return presentVerification(
      verification,
      await this.proposals.forVerification(user.id, verification),
    );
  }

  @Delete(':id')
  @HttpCode(204)
  async remove(
    @CurrentUser() user: AuthenticatedUser,
    @Param() { id }: IdParam,
  ): Promise<void> {
    await this.deleteVerification.execute(user.id, id);
  }
}
