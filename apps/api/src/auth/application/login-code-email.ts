export type EmailLocale = 'es' | 'en';

export interface LoginCodeEmail {
  subject: string;
  text: string;
  html: string;
}

const COPY = {
  es: {
    subject: (code: string) => `Tu código de Cashback Audit: ${code}`,
    intro: 'Tu código para iniciar sesión en Cashback Audit es:',
    expires: (minutes: number) =>
      `Vence en ${minutes} minutos y solo se puede usar una vez.`,
    ignore: 'Si no lo pediste, puedes ignorar este correo.',
  },
  en: {
    subject: (code: string) => `Your Cashback Audit code: ${code}`,
    intro: 'Your code to sign in to Cashback Audit is:',
    expires: (minutes: number) =>
      `It expires in ${minutes} minutes and can only be used once.`,
    ignore: "If you didn't request it, you can ignore this email.",
  },
} as const;

/** Plain text + minimal HTML, no links. */
export function buildLoginCodeEmail(
  locale: EmailLocale,
  code: string,
  ttlMinutes: number,
): LoginCodeEmail {
  const c = COPY[locale];
  const expires = c.expires(ttlMinutes);
  return {
    subject: c.subject(code),
    text: `${c.intro}\n\n${code}\n\n${expires}\n${c.ignore}\n`,
    html:
      `<div style="font-family:Arial,Helvetica,sans-serif;font-size:16px;color:#111">` +
      `<p>${c.intro}</p>` +
      `<p style="font-size:32px;font-weight:bold;letter-spacing:6px">${code}</p>` +
      `<p>${expires}</p><p style="color:#666">${c.ignore}</p></div>`,
  };
}
