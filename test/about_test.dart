import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moonpetal/app.dart';
import 'package:moonpetal/src/about_view.dart';
import 'package:moonpetal/src/link_launcher.dart';

import 'helpers/fakes.dart';

// ignore: deprecated_member_use
class NoNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw StateError('About must never make a network call.');
  }
}

class RecordingLinkLauncher implements LinkLauncher {
  final List<Uri> opened = [];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

void main() {
  const repositoryUrl = 'https://github.com/DECSolutionsGroupLLC/Moonpetal';

  setUp(() => HttpOverrides.global = NoNetworkHttpOverrides());
  tearDown(() => HttpOverrides.global = null);

  testWidgets(
    'About is reachable from the main UI and states privacy and open source',
    (tester) async {
      final launcher = RecordingLinkLauncher();

      await tester.pumpWidget(
        MoonpetalApp(
          clock: FixedClock(DateTime(2026, 11, 19, 9)),
          store: InMemoryAppStore(),
          linkLauncher: launcher,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('aboutButton')), findsOneWidget);
      await tester.tap(find.byKey(const Key('aboutButton')));
      await tester.pumpAndSettle();

      expect(find.byType(AboutView), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      expect(find.byKey(const Key('aboutPrivacyStatement')), findsOneWidget);
      expect(
        find.textContaining('log entries and Settings stay on this device'),
        findsOneWidget,
      );
      expect(find.textContaining('never sent anywhere'), findsOneWidget);
      expect(find.textContaining('open source'), findsOneWidget);
      expect(find.byKey(const Key('aboutRepositoryLink')), findsOneWidget);
      expect(find.text(repositoryUrl), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the repository link hands it to an external opener only',
    (tester) async {
      final launcher = RecordingLinkLauncher();

      await tester.pumpWidget(
        MoonpetalApp(
          clock: FixedClock(DateTime(2026, 11, 19, 9)),
          store: InMemoryAppStore(),
          linkLauncher: launcher,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('aboutButton')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('aboutRepositoryLink')));
      await tester.pumpAndSettle();

      expect(launcher.opened.single.toString(), equals(repositoryUrl));
    },
  );

  testWidgets(
    'About stays reachable once the user has logged data',
    (tester) async {
      await tester.pumpWidget(
        MoonpetalApp(
          clock: FixedClock(DateTime(2026, 11, 19, 9)),
          store: InMemoryAppStore(
            document: <String, Object?>{
              'logEntries': <Object?>[
                <String, Object?>{'date': '2026-11-18', 'periodDay': true},
              ],
            },
          ),
          linkLauncher: RecordingLinkLauncher(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('aboutButton')), findsOneWidget);
    },
  );

  test('the Android manifest declares no internet permission', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, isNot(contains('android.permission.INTERNET')));
  });
}
