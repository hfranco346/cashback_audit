import 'package:get/get.dart';

import '../../auth/presentation/session_controller.dart';
import '../../credits/presentation/credits_controller.dart';
import '../../subscription/presentation/subscription_controller.dart';

/// Start-up work for the signed-in area: restores the user (works offline)
/// and refreshes the subscription status and the credit balance.
class HomeController extends GetxController {
  HomeController({
    required this._session,
    required this._subscription,
    required this._credits,
  });

  final SessionController _session;
  final SubscriptionController _subscription;
  final CreditsController _credits;

  @override
  void onReady() {
    super.onReady();
    _session.restore();
    _subscription.fetchStatus();
    _credits.fetch();
  }
}
