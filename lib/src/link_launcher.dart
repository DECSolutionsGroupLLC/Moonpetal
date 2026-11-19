/// The boundary for handing an external link to the platform.
///
/// Moonpetal never fetches a link itself: it asks the operating system to open
/// it in the user's browser. That keeps the app free of internet permission,
/// network calls, and any transmission of user data. Tests substitute a
/// recorder so no platform channel is involved.
abstract class LinkLauncher {
  const LinkLauncher();

  /// Opens [uri] in an external application. Returns true when it was opened.
  Future<bool> open(Uri uri);
}

/// Used where no external link should be opened.
class NoOpLinkLauncher implements LinkLauncher {
  const NoOpLinkLauncher();

  @override
  Future<bool> open(Uri uri) async => false;
}
