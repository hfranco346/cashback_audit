import { cleanKeywords } from './merchant.use-cases.js';

describe('cleanKeywords', () => {
  it('trims, drops empties and de-duplicates case-insensitively', () => {
    expect(
      cleanKeywords([' WAL MART ', 'wal mart', '', '  ', 'WALMART SUC']),
    ).toEqual(['WAL MART', 'WALMART SUC']);
  });
});
