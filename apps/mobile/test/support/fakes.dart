import 'package:cashback_audit/core/routing/app_navigator.dart';
import 'package:cashback_audit/features/auth/domain/auth_entities.dart';
import 'package:cashback_audit/features/auth/domain/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

SharedPreferencesAsync freshPrefs() {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  return SharedPreferencesAsync();
}

class FakeNavigator implements AppNavigator {
  final routes = <String>[];
  final notices = <String>[];
  @override
  void offAll(String route) => routes.add(route);
  @override
  void showNotice(String title, String message) => notices.add(title);
  int pops = 0;
  Object? lastPopResult;
  @override
  void pop({Object? result}) {
    pops++;
    lastPopResult = result;
  }

  /// Value `pushForResult` completes with (scripted by the test).
  Object? nextResult;
  final pushedForResult = <String>[];
  final pushedForResultArgs = <Object?>[];
  @override
  Future<T?> pushForResult<T>(String route, {Object? arguments}) async {
    pushedForResult.add(route);
    pushedForResultArgs.add(arguments);
    return nextResult as T?;
  }

  final pushed = <String>[];
  final pushedArgs = <Object?>[];
  final replaced = <String>[];
  final replacedArgs = <Object?>[];
  @override
  void push(String route, {Object? arguments}) {
    pushed.add(route);
    pushedArgs.add(arguments);
  }

  @override
  void replace(String route, {Object? arguments}) {
    replaced.add(route);
    replacedArgs.add(arguments);
  }
}

class FakeGoogle implements GoogleIdentityProvider {
  FakeGoogle({this.token = 'google-id-token', this.error});
  final String token;
  final Object? error;

  @override
  Future<String> fetchIdToken() async {
    if (error != null) throw error!;
    return token;
  }
}

class FakeApple implements AppleIdentityProvider {
  FakeApple({this.credential, this.error, this.supported = true});
  final AppleCredential? credential;
  final Object? error;
  final bool supported;

  @override
  bool get isSupported => supported;

  @override
  Future<AppleCredential> fetchCredential() async {
    if (error != null) throw error!;
    return credential ?? const AppleCredential(identityToken: 'apple-token');
  }
}
