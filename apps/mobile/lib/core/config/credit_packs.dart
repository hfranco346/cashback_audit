/// Parses the `CREDIT_PACKS` dart-define (`productId:credits` pairs separated
/// by commas, e.g. `credits_3:3,credits_10:10`). It must mirror the backend
/// `CREDIT_PACKS` setting: only these product ids grant credits there.
/// Malformed pairs are skipped.
Map<String, int> parseCreditPacks(String raw) {
  final packs = <String, int>{};
  for (final pair in raw.split(',')) {
    final parts = pair.split(':');
    if (parts.length != 2) continue;
    final id = parts[0].trim();
    final credits = int.tryParse(parts[1].trim());
    if (id.isEmpty || credits == null || credits <= 0) continue;
    packs[id] = credits;
  }
  return packs;
}
