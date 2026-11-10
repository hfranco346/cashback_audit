import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _chain = [
  AppLifecycleState.resumed,
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
  AppLifecycleState.paused,
];

/// Moves the app to [target] through the valid intermediate states, as the
/// engine does (an `AppLifecycleListener` rejects skipping states).
void setAppLifecycle(
  TestWidgetsFlutterBinding binding,
  AppLifecycleState target,
) {
  var i = _chain.indexOf(binding.lifecycleState ?? AppLifecycleState.resumed);
  final to = _chain.indexOf(target);
  while (i != to) {
    i += to > i ? 1 : -1;
    binding.handleAppLifecycleStateChanged(_chain[i]);
  }
}
