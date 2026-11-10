import 'package:url_launcher/url_launcher.dart';

import '../domain/mail_launcher.dart';

class UrlLauncherMailLauncher implements MailLauncher {
  const UrlLauncherMailLauncher();

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }
}
