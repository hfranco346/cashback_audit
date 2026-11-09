import 'package:get/get.dart';

/// Selected tab of the navigation shell (0 Home, 1 History, 2 Categories,
/// 3 Profile).
class ShellController extends GetxController {
  final tab = 0.obs;

  void select(int index) {
    if (index < 0 || index > 3) return;
    tab.value = index;
  }
}
