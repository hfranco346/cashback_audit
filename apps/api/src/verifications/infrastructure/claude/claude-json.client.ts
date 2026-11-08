import Anthropic from '@anthropic-ai/sdk';
import { zodOutputFormat } from '@anthropic-ai/sdk/helpers/zod';
import { Inject, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { z } from 'zod';
import type { Env } from '../../../config/env.js';
import { DomainError } from '../../../shared/domain/domain-error.js';
import {
  ExtractionFailedError,
  ExtractionUnavailableError,
  UnreadableStatementError,
} from '../../domain/verification-errors.js';

export const ANTHROPIC_CLIENT = Symbol('ANTHROPIC_CLIENT');

export type ClaudeTask = 'extraction' | 'classification';

export interface JsonRequest<T extends z.ZodType> {
  /** Selects the configured model for this kind of work. */
  task: ClaudeTask;
  schema: T;
  /**
   * Schema used to validate the parsed JSON. Defaults to `schema`; callers that
   * run their own strict validation afterwards can pass a more lenient one.
   */
  validationSchema?: z.ZodType;
  system: string;
  content: Anthropic.MessageParam['content'];
  maxTokens: number;
}

/**
 * Thin wrapper over the Anthropic SDK: one structured-output call, streamed
 * (large outputs), with SDK errors translated into domain errors that never
 * carry upstream messages or credentials.
 */
@Injectable()
export class ClaudeJsonClient {
  private readonly logger = new Logger(ClaudeJsonClient.name);
  readonly models: Record<ClaudeTask, string>;
  private readonly hasKey: boolean;

  constructor(
    @Inject(ANTHROPIC_CLIENT) private readonly client: Anthropic,
    config: ConfigService<Env, true>,
  ) {
    this.models = {
      extraction: config.get('ANTHROPIC_EXTRACTION_MODEL', { infer: true }),
      classification: config.get('ANTHROPIC_CLASSIFICATION_MODEL', {
        infer: true,
      }),
    };
    this.hasKey = config.get('ANTHROPIC_API_KEY', { infer: true }).length > 0;
  }

  /** Returns the parsed (loosely validated) JSON payload. */
  async requestJson<T extends z.ZodType>(
    request: JsonRequest<T>,
  ): Promise<z.infer<T>> {
    if (!this.hasKey) {
      this.logger.error('ANTHROPIC_API_KEY is not configured');
      throw new ExtractionUnavailableError();
    }
    let message: Anthropic.Message;
    try {
      message = await this.client.messages
        .stream({
          model: this.models[request.task],
          max_tokens: request.maxTokens,
          system: request.system,
          messages: [{ role: 'user', content: request.content }],
          output_config: { format: zodOutputFormat(request.schema) },
        })
        .finalMessage();
    } catch (error) {
      throw this.mapError(error);
    }
    this.logUsage(request.task, message);

    if (message.stop_reason === 'refusal') {
      throw new UnreadableStatementError(
        'The statement could not be processed.',
      );
    }
    if (message.stop_reason === 'max_tokens') {
      throw new UnreadableStatementError(
        'The statement is too long to analyze in one go.',
      );
    }
    const text = message.content.find((block) => block.type === 'text');
    if (!text || text.type !== 'text') throw new ExtractionFailedError();
    let json: unknown;
    try {
      json = JSON.parse(text.text);
    } catch {
      throw new ExtractionFailedError();
    }
    const parsed = (request.validationSchema ?? request.schema).safeParse(json);
    if (!parsed.success) throw new ExtractionFailedError();
    return parsed.data as z.infer<T>;
  }

  /** Plain-text answer (no structured output); same error mapping. */
  async requestText(request: {
    task: ClaudeTask;
    system: string;
    content: Anthropic.MessageParam['content'];
    maxTokens: number;
  }): Promise<string> {
    if (!this.hasKey) {
      this.logger.error('ANTHROPIC_API_KEY is not configured');
      throw new ExtractionUnavailableError();
    }
    let message: Anthropic.Message;
    try {
      message = await this.client.messages
        .stream({
          model: this.models[request.task],
          max_tokens: request.maxTokens,
          system: request.system,
          messages: [{ role: 'user', content: request.content }],
        })
        .finalMessage();
    } catch (error) {
      throw this.mapError(error);
    }
    this.logUsage(request.task, message);
    if (
      message.stop_reason === 'refusal' ||
      message.stop_reason === 'max_tokens'
    ) {
      throw new ExtractionFailedError();
    }
    const text = message.content.find((block) => block.type === 'text');
    if (!text || text.type !== 'text' || !text.text.trim()) {
      throw new ExtractionFailedError();
    }
    return text.text.trim();
  }

  /** Token usage per call, for cost monitoring (no content is logged). */
  private logUsage(task: ClaudeTask, message: Anthropic.Message): void {
    const usage = message.usage as Anthropic.Usage | undefined;
    if (!usage) return;
    this.logger.log(
      `Claude usage task=${task} model=${message.model} input=${usage.input_tokens} output=${usage.output_tokens} cacheRead=${usage.cache_read_input_tokens ?? 0} cacheWrite=${usage.cache_creation_input_tokens ?? 0}`,
    );
  }

  private mapError(error: unknown): DomainError {
    if (error instanceof DomainError) return error;
    if (error instanceof Anthropic.APIError) {
      // Log status + request id only: messages may echo request details.
      this.logger.error(
        `Anthropic API error status=${error.status ?? 'n/a'} requestId=${error.requestID ?? 'n/a'}`,
      );
      // Invalid-request errors describe the request shape (schema, model,
      // limits), never credentials; log them to make 400s diagnosable.
      if (error.status === 400) {
        const body = error.error as
          { error?: { type?: string; message?: string } } | undefined;
        this.logger.error(
          `Anthropic invalid request: type=${body?.error?.type ?? 'n/a'} message=${(body?.error?.message ?? 'n/a').slice(0, 500)}`,
        );
      }
      if (error instanceof Anthropic.APIConnectionError)
        return new ExtractionUnavailableError();
      switch (error.status) {
        case 400:
        case 413:
        case 422:
          return new UnreadableStatementError();
        case 401:
        case 403:
        case 404:
          return new ExtractionUnavailableError();
        case 429:
        case 503:
        case 529:
          return new ExtractionUnavailableError();
        default:
          return new ExtractionFailedError();
      }
    }
    this.logger.error(
      `Unexpected extraction error: ${error instanceof Error ? error.name : 'unknown'}`,
    );
    return new ExtractionFailedError();
  }
}
