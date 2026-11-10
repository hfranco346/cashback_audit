import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import type { Response } from 'express';
import { DomainError, type DomainErrorKind } from '../domain/domain-error.js';

const KIND_TO_STATUS: Record<DomainErrorKind, number> = {
  VALIDATION: HttpStatus.BAD_REQUEST,
  UNAUTHENTICATED: HttpStatus.UNAUTHORIZED,
  PAYMENT_REQUIRED: HttpStatus.PAYMENT_REQUIRED,
  FORBIDDEN: HttpStatus.FORBIDDEN,
  NOT_FOUND: HttpStatus.NOT_FOUND,
  CONFLICT: HttpStatus.CONFLICT,
  GONE: HttpStatus.GONE,
  RATE_LIMITED: HttpStatus.TOO_MANY_REQUESTS,
  UNPROCESSABLE: HttpStatus.UNPROCESSABLE_ENTITY,
  UPSTREAM_FAILURE: HttpStatus.BAD_GATEWAY,
  UPSTREAM_UNAVAILABLE: HttpStatus.SERVICE_UNAVAILABLE,
};

const STATUS_TO_CODE: Record<number, string> = {
  400: 'VALIDATION_ERROR',
  401: 'UNAUTHORIZED',
  402: 'SUBSCRIPTION_REQUIRED',
  403: 'FORBIDDEN',
  404: 'NOT_FOUND',
  409: 'CONFLICT',
  413: 'PAYLOAD_TOO_LARGE',
  415: 'UNSUPPORTED_MEDIA_TYPE',
  422: 'UNPROCESSABLE',
  429: 'TOO_MANY_REQUESTS',
  502: 'UPSTREAM_ERROR',
  503: 'SERVICE_UNAVAILABLE',
};

export interface ErrorBody {
  statusCode: number;
  code: string;
  message: string;
  details?: unknown;
}

/** Every error leaves the API as `{ statusCode, code, message, details? }`. */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const response = host.switchToHttp().getResponse<Response>();
    const body = this.toBody(exception);
    const retryAfter = (body.details as { retryAfterSeconds?: unknown })
      ?.retryAfterSeconds;
    if (body.statusCode === 429 && typeof retryAfter === 'number') {
      response.setHeader('Retry-After', String(retryAfter));
    }
    response.status(body.statusCode).json(body);
  }

  private toBody(exception: unknown): ErrorBody {
    if (exception instanceof DomainError) {
      return {
        statusCode: KIND_TO_STATUS[exception.kind],
        code: exception.code,
        message: exception.message,
        ...(exception.details !== undefined && { details: exception.details }),
      };
    }
    if (exception instanceof HttpException) {
      const statusCode = exception.getStatus();
      const payload = exception.getResponse();
      const fallbackCode = STATUS_TO_CODE[statusCode] ?? 'ERROR';
      if (typeof payload === 'string') {
        return { statusCode, code: fallbackCode, message: payload };
      }
      const obj = payload as Record<string, unknown>;
      const code = typeof obj.code === 'string' ? obj.code : fallbackCode;
      if (Array.isArray(obj.message)) {
        return {
          statusCode,
          code,
          message: 'Validation failed',
          details: obj.message,
        };
      }
      return {
        statusCode,
        code,
        message:
          typeof obj.message === 'string' ? obj.message : exception.message,
        ...(obj.details !== undefined && { details: obj.details }),
      };
    }
    this.logger.error(
      exception instanceof Error ? exception.stack : String(exception),
    );
    return {
      statusCode: 500,
      code: 'INTERNAL_ERROR',
      message: 'Internal server error',
    };
  }
}
