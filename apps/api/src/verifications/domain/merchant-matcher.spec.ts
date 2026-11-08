import { MerchantMatcher, normalizeText } from './merchant-matcher.js';

const merchants = [
  {
    id: 'walmart',
    name: 'Walmart',
    keywords: ['WAL MART', 'WALMART SUC'],
    categoryId: 'super',
  },
  { id: 'soriana', name: 'Soriana', keywords: [], categoryId: 'super' },
  {
    id: 'cafe',
    name: 'Café Punta del Cielo',
    keywords: ['PUNTA CIELO'],
    categoryId: 'food',
  },
  { id: 'oxxo', name: 'Oxxo', keywords: ['OXXO GAS'], categoryId: 'gas' },
  { id: 'oxxo-shop', name: 'Oxxo Tienda', keywords: [], categoryId: 'conv' },
  { id: 'ab', name: 'AB', keywords: ['X'], categoryId: 'tiny' },
];
const matcher = new MerchantMatcher(merchants);

describe('normalizeText', () => {
  it('strips accents, case and punctuation', () => {
    expect(normalizeText('  CAFÉ-Punta*del   Cielo #12 ')).toBe(
      'cafe punta del cielo 12',
    );
  });
});

describe('MerchantMatcher', () => {
  it.each([
    ['WALMART SUC 123 CDMX', 'walmart'],
    ['WAL MART SUPERCENTER', 'walmart'],
    ['WAL-MART*1234', 'walmart'],
    ['Soriana Hiper Sur', 'soriana'],
    ['CAFE PUNTA DEL CIELO POLANCO', 'cafe'],
    ['PUNTA CIELO 22', 'cafe'],
    ['café punta del cielo', 'cafe'],
  ])('matches %s -> %s', (text, id) => {
    expect(matcher.match(text)?.id).toBe(id);
  });

  it('returns null when nothing matches', () => {
    expect(matcher.match('UBER TRIP HELP.UBER.COM')).toBeNull();
    expect(matcher.match('')).toBeNull();
  });

  it('prefers the longest matching keyword', () => {
    expect(matcher.match('OXXO GAS 5521')?.id).toBe('oxxo');
    expect(matcher.match('OXXO TIENDA 5521')?.id).toBe('oxxo-shop');
  });

  it('ignores needles shorter than 3 characters', () => {
    expect(matcher.match('AB X')).toBeNull();
  });
});
