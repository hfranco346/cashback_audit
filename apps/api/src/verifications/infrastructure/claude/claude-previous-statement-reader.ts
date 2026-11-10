import { Injectable } from '@nestjs/common';
import { z } from 'zod';
import {
  PreviousStatementReader,
  type PreviousStatementProgram,
} from '../../domain/statement-extractor.js';
import { NotAStatementError } from '../../domain/verification-errors.js';
import { ClaudeJsonClient } from './claude-json.client.js';
import {
  PREVIOUS_STATEMENT_SYSTEM_PROMPT,
  parsePreviousStatement,
  previousStatementOutputSchema,
} from './previous-statement-schema.js';

@Injectable()
export class ClaudePreviousStatementReader extends PreviousStatementReader {
  constructor(private readonly claude: ClaudeJsonClient) {
    super();
  }

  async read(
    pdf: Buffer,
  ): Promise<{ programs: PreviousStatementProgram[]; model: string }> {
    const raw = await this.claude.requestJson({
      task: 'extraction',
      schema: previousStatementOutputSchema,
      validationSchema: z.record(z.string(), z.unknown()),
      system: PREVIOUS_STATEMENT_SYSTEM_PROMPT,
      maxTokens: 4000,
      content: [
        {
          type: 'document',
          source: {
            type: 'base64',
            media_type: 'application/pdf',
            data: pdf.toString('base64'),
          },
        },
        {
          type: 'text',
          text: 'Read the rewards program balances of this statement as specified.',
        },
      ],
    });
    const programs = parsePreviousStatement(raw);
    if (!programs) throw new NotAStatementError();
    return { programs, model: this.claude.models.extraction };
  }
}
