import 'package:get/get.dart';

import '../../features/verifications/domain/verification_events.dart';
import 'app_routes.dart';

/// `GetMaterialApp.routingCallback`: when the user comes back to Home from a
/// pushed route (verify, progress, confirm, result, ...), whatever happened
/// there may have changed the verifications, so Home and History refresh.
void notifyOnReturnToHome(Routing? routing, VerificationEvents events) {
  if (routing == null) return;
  if (routing.isBottomSheet == true || routing.isDialog == true) return;
  if (routing.isBack == true && routing.current == Routes.home) {
    events.notify();
  }
}
