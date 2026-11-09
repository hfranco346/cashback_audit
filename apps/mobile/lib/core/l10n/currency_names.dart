/// Display names of the currencies the app suggests, per language. Unknown
/// codes have no name: the UI shows the ISO code alone.
const _names = <String, (String es, String en)>{
  'USD': ('Dólar estadounidense', 'US dollar'),
  'EUR': ('Euro', 'Euro'),
  'MXN': ('Peso mexicano', 'Mexican peso'),
  'GTQ': ('Quetzal', 'Guatemalan quetzal'),
  'HNL': ('Lempira', 'Honduran lempira'),
  'CRC': ('Colón costarricense', 'Costa Rican colón'),
  'COP': ('Peso colombiano', 'Colombian peso'),
  'PEN': ('Sol peruano', 'Peruvian sol'),
  'CLP': ('Peso chileno', 'Chilean peso'),
  'ARS': ('Peso argentino', 'Argentine peso'),
  'BRL': ('Real brasileño', 'Brazilian real'),
  'DOP': ('Peso dominicano', 'Dominican peso'),
  'NIO': ('Córdoba', 'Nicaraguan córdoba'),
  'PAB': ('Balboa', 'Panamanian balboa'),
  'GBP': ('Libra esterlina', 'Pound sterling'),
  'CAD': ('Dólar canadiense', 'Canadian dollar'),
};

/// "Lempira" for `HNL`, or `null` when the code has no known name.
String? currencyName(String code, String languageCode) {
  final n = _names[code.toUpperCase()];
  if (n == null) return null;
  return languageCode == 'en' ? n.$2 : n.$1;
}

/// `HNL · Lempira`, or just the code.
String currencyTitle(String code, String languageCode) {
  final name = currencyName(code, languageCode);
  return name == null ? code : '$code · $name';
}
