import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/strings.dart';
import '../../auth/presentation/session_controller.dart';

/// Temporary shell; replaced by the real home in T8.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionController>();
    return Scaffold(
      appBar: AppBar(title: const Text(S.appName)),
      body: Center(
        child: FilledButton(
          onPressed: session.signOut,
          child: const Text('Salir'),
        ),
      ),
    );
  }
}
