import 'package:flutter_test/flutter_test.dart';

import 'package:moonpetal/app.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets(
    'first run shows a pink empty state that tells the user where to start',
    (tester) async {
      final store = InMemoryAppStore();

      await tester.pumpWidget(
        MoonpetalApp(
          clock: FixedClock(DateTime(2026, 11, 18, 9)),
          store: store,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome to Moonpetal'), findsOneWidget);
      expect(
        find.textContaining('Start by marking today as a period day'),
        findsOneWidget,
      );
      expect(find.text('Today, Wednesday 18 November 2026'), findsOneWidget);
    },
  );

  testWidgets(
    'an existing document does not show the first-run empty state',
    (tester) async {
      final store = InMemoryAppStore(
        document: <String, Object?>{
          'logEntries': <Object?>[<String, Object?>{'date': '2026-11-17'}],
        },
      );

      await tester.pumpWidget(MoonpetalApp(store: store));
      await tester.pumpAndSettle();

      expect(find.text('Welcome to Moonpetal'), findsNothing);
      expect(
        find.text('Your entries are stored on this device.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'stored settings alone still leave the user on the first-run state',
    (tester) async {
      final store = InMemoryAppStore(
        document: <String, Object?>{
          'settings': <String, Object?>{'theme': 'pink'},
        },
      );

      await tester.pumpWidget(MoonpetalApp(store: store));
      await tester.pumpAndSettle();

      expect(find.text('Welcome to Moonpetal'), findsOneWidget);
    },
  );
}
