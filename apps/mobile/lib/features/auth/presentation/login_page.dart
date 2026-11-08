import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'login_controller.dart';
import 'widgets/login_view.dart';

class LoginPage extends GetView<LoginController> {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => LoginView(
        onGoogle: controller.signInWithGoogle,
        onApple: controller.signInWithApple,
        showApple: controller.showApple,
        loading: controller.loading.value,
        errorMessage: controller.errorMessage.value,
      ),
    );
  }
}
