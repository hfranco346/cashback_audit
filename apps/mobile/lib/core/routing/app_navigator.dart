import 'package:flutter/material.dart';
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

/// Key of the app-wide [ScaffoldMessenger] (wired in `CashbackAuditApp`), so
/// context-less code can show notices without GetX snackbars.
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

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
  Future<T?> pushForResult<T>(String route, {Object? arguments}) async {
    // GetX builds a `GetPageRoute<dynamic>`; asking `toNamed` for a concrete
    // `T` makes `Navigator.pushNamed` cast it to `Route<T>` and throw a
    // TypeError before the page opens. Push untyped and narrow the result.
    final result = await Get.toNamed<dynamic>(route, arguments: arguments);
    return result is T ? result : null;
  }

  @override
  void pop({Object? result}) => Get.back<Object?>(result: result);

  @override
  void showNotice(String title, String message) {
    final messenger = appMessengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (message.isNotEmpty) Text(message),
            ],
          ),
        ),
      );
  }
}
