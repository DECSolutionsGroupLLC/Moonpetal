import 'package:url_launcher/url_launcher.dart';

import 'link_launcher.dart';

/// The platform side of opening the public repository link.
///
/// The URL is handed to the operating system as an external VIEW intent; the
/// app itself never fetches it, stores it, or sends any user data along with
/// it. No internet permission is added to the app for this.
class NativeLinkLauncher implements LinkLauncher {
  const NativeLinkLauncher();

  @override
  Future<bool> open(Uri uri) => launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );
}
