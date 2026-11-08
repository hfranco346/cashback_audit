import 'package:get/get.dart';

/// Navigation port so controllers stay testable without a running app.
abstract class AppNavigator {
  /// Replaces the whole stack with [route].
  void offAll(String route);

  /// Pushes [route] on top of the current page.
  void push(String route, {Object? arguments});

  /// Replaces the current page with [route].
  void replace(String route, {Object? arguments});

  /// Pushes [route] and completes with the value the page pops with.
  Future<T?> pushForResult<T>(String route, {Object? arguments});

  /// Pops the current page, optionally handing [result] to the caller of
  /// [pushForResult].
  void pop({Object? result});

  void showNotice(String title, String message);
}

class GetAppNavigator implements AppNavigator {
  @override
  void offAll(String route) => Get.offAllNamed<void>(route);

  @override
  void push(String route, {Object? arguments}) =>
      Get.toNamed<void>(route, arguments: arguments);

  @override
  void replace(String route, {Object? arguments}) =>
      Get.offNamed<void>(route, arguments: arguments);

  @override
  Future<T?> pushForResult<T>(String route, {Object? arguments}) async =>
      Get.toNamed<T>(route, arguments: arguments);

  @override
  void pop({Object? result}) => Get.back<Object?>(result: result);

  @override
  void showNotice(String title, String message) => Get.snackbar(title, message);
}
