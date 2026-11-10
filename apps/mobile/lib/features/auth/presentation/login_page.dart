import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'email_sign_in_controller.dart';
import 'login_controller.dart';
import 'widgets/email_sign_in_section.dart';
import 'widgets/login_view.dart';

class LoginPage extends GetView<LoginController> {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final email = Get.find<EmailSignInController>();
    return Obx(
      () => LoginView(
        emailSection: EmailSignInSection(controller: email, login: controller),
        showAlternatives: email.stage.value == EmailStage.address,
        onGoogle: controller.signInWithGoogle,
        onApple: controller.signInWithApple,
        showApple: controller.showApple,
        showGoogle: controller.showGoogle,
        onDevSignIn: controller.showDevSignIn
            ? controller.signInForDevelopment
            : null,
        loading: controller.loading.value,
        errorMessage: controller.errorMessage.value,
      ),
    );
  }
}
