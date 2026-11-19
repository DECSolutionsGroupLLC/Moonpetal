import 'package:flutter/material.dart';

import 'link_launcher.dart';
import 'theme.dart';

/// The public repository, in plain view for anyone who wants to inspect the
/// code behind the privacy promise.
final Uri aboutRepositoryUri = Uri.parse(
  'https://github.com/DECSolutionsGroupLLC/Moonpetal',
);

/// States, in plain language, that data stays on the device and that the code
/// is open for inspection. Tapping the link hands the URL to the platform; the
/// app never fetches it itself.
class AboutView extends StatelessWidget {
  const AboutView({super.key, required this.linkLauncher});

  /// Hands the repository URL to an external opener. Injected so the link can
  /// be verified in a widget test without a platform channel or network call.
  final LinkLauncher linkLauncher;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your data stays with you',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: MoonpetalColors.deepPink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'All your log entries and Settings stay on this device and are '
                'never sent anywhere. There is no account, no cloud, no '
                'analytics, and no network permission.',
                key: const Key('aboutPrivacyStatement'),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Text(
                'Open source',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: MoonpetalColors.deepPink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Moonpetal is open source. Anyone can inspect the code.',
                key: const Key('aboutOpenSourceStatement'),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Semantics(
                link: true,
                child: InkWell(
                  key: const Key('aboutRepositoryLink'),
                  onTap: () => linkLauncher.open(aboutRepositoryUri),
                  child: Text(
                    aboutRepositoryUri.toString(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: MoonpetalColors.deepPink,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No account. No server. No network calls.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
