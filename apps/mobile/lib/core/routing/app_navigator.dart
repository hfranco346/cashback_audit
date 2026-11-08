import 'package:get/get.dart';

/// Navigation port so controllers stay testable without a running app.
abstract class AppNavigator {
  /// Replaces the whole stack with [route].
  void offAll(String route);
  void showNotice(String title, String message);
}

class GetAppNavigator implements AppNavigator {
  @override
  void offAll(String route) => Get.offAllNamed<void>(route);

  @override
  void showNotice(String title, String message) => Get.snackbar(title, message);
}
