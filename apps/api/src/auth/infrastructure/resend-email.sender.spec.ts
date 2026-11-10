import { ConfigService } from '@nestjs/config';
import { ResendEmailSender } from './resend-email.sender.js';

const mail = {
  to: 'ana@example.com',
  subject: 'Your Cashback Audit code: 123456',
  text: 'Your code is 123456',
  html: '<p>123456</p>',
  code: '123456',
};

function build(response: Response) {
  const sender = new ResendEmailSender(
    new ConfigService({
      RESEND_API_KEY: 're_test_key',
      EMAIL_FROM: 'Cashback Audit <no-reply@neargps.net>',
    }) as never,
  );
  const calls: { url: string; init: RequestInit }[] = [];
  sender.fetchFn = (async (url: string, init: RequestInit) => {
    calls.push({ url, init });
    return response;
  }) as typeof fetch;
  const lines: string[] = [];
  (sender as unknown as { logger: Record<string, unknown> }).logger.error = (
    m: string,
  ) => lines.push(m);
  return { sender, calls, lines };
}

describe('ResendEmailSender', () => {
  it('posts the message to the Resend API with the key and sender', async () => {
    const { sender, calls } = build(
      new Response('{"id":"x"}', { status: 200 }),
    );
    await sender.send(mail);
    expect(calls).toHaveLength(1);
    expect(calls[0]!.url).toBe('https://api.resend.com/emails');
    const headers = calls[0]!.init.headers as Record<string, string>;
    expect(headers.Authorization).toBe('Bearer re_test_key');
    expect(JSON.parse(calls[0]!.init.body as string)).toEqual({
      from: 'Cashback Audit <no-reply@neargps.net>',
      to: ['ana@example.com'],
      subject: mail.subject,
      text: mail.text,
      html: mail.html,
    });
  });

  it('throws when Resend rejects the message and never logs the code', async () => {
    const { sender, lines } = build(
      new Response('{"name":"validation_error","message":"bad from"}', {
        status: 422,
      }),
    );
    await expect(sender.send(mail)).rejects.toThrow('Resend responded 422');
    expect(lines.join('\n')).toContain('422');
    expect(lines.join('\n')).not.toContain('123456');
  });
});
