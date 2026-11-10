import { ConfigService } from '@nestjs/config';
import { LogEmailSender } from './log-email.sender.js';

const mail = {
  to: 'ana@example.com',
  subject: 'Your Cashback Audit code: 123456',
  text: '123456',
  html: '<p>123456</p>',
  code: '123456',
};

function capture(env: string) {
  const sender = new LogEmailSender(
    new ConfigService({ NODE_ENV: env }) as never,
  );
  const lines: string[] = [];
  const logger = (sender as unknown as { logger: Record<string, unknown> })
    .logger;
  for (const level of ['log', 'warn'])
    logger[level] = (m: string) => lines.push(m);
  return { sender, lines };
}

describe('LogEmailSender', () => {
  it('prints the code outside production', async () => {
    const { sender, lines } = capture('development');
    await sender.send(mail);
    expect(lines.join('\n')).toContain('123456');
  });

  it('never prints the code in production', async () => {
    const { sender, lines } = capture('production');
    await sender.send(mail);
    expect(lines.join('\n')).not.toContain('123456');
    expect(lines.join('\n')).not.toContain('ana@example.com');
  });
});
