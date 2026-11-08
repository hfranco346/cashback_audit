import 'credit_packs.dart';

/// Build-time configuration injected with `--dart-define`.
///
/// Example:
/// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1`
abstract final class AppConfig {
  /// Backend base URL. Android emulators reach the host machine at 10.0.2.2.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );

  /// Web OAuth client id registered in the backend (`GOOGLE_CLIENT_IDS`).
  /// Used as `serverClientId` so the ID token audience matches the backend.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  /// iOS OAuth client id (optional when `GoogleService-Info.plist` is bundled).
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  static const String revenueCatIosKey = String.fromEnvironment(
    'REVENUECAT_IOS_KEY',
  );

  static const String revenueCatAndroidKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_KEY',
  );

  /// Consumable credit packs sold through RevenueCat: `productId:credits`
  /// pairs. Must mirror the backend `CREDIT_PACKS` setting.
  static const String _creditPacksRaw = String.fromEnvironment(
    'CREDIT_PACKS',
    defaultValue: 'credits_3:3,credits_10:10',
  );

  static final Map<String, int> creditPacks = parseCreditPacks(_creditPacksRaw);
}
