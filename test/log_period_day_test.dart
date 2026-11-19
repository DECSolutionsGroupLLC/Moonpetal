import 'package:flutter_test/flutter_test.dart';

import 'package:moonpetal/app.dart';

import 'helpers/fakes.dart';

void main() {
  final today = DateTime(2026, 11, 18, 9);

  Future<void> pumpApp(
    WidgetTester tester,
    InMemoryAppStore store, [
    DateTime? now,
  ]) async {
    await tester.pumpWidget(
      MoonpetalApp(clock: FixedClock(now ?? today), store: store),
    );
    await tester.pumpAndSettle();
  }

  // Controls added above the logging button shift it down the scroll view, so
  // bring it into view before tapping rather than assuming a fixed position.
  Future<void> tapLogToday(WidgetTester tester) async {
    final finder = find.text('Log today as a period day');
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'one tap logs today as a period day and shows it in the history list',
    (tester) async {
      final store = InMemoryAppStore();
      await pumpApp(tester, store);

      expect(find.text('Log today as a period day'), findsOneWidget);

      await tapLogToday(tester);

      expect(find.text('Wednesday 18 November 2026'), findsOneWidget);
      expect(find.text('Today is logged'), findsOneWidget);
    },
  );

  testWidgets(
    'a logged period day survives a restart against the same store',
    (tester) async {
      final store = InMemoryAppStore();
      await pumpApp(tester, store);
      await tapLogToday(tester);

      await pumpApp(tester, store);

      expect(find.text('Wednesday 18 November 2026'), findsOneWidget);
      expect(find.text('Today is logged'), findsOneWidget);
    },
  );

  testWidgets(
    'a logged period day survives a fresh store over the same saved data',
    (tester) async {
      final backing = <String, Object?>{};

      await tester.pumpWidget(
        MoonpetalApp(
          clock: FixedClock(today),
          store: SharedInMemoryAppStore(backing),
        ),
      );
      await tester.pumpAndSettle();
      await tapLogToday(tester);

      await tester.pumpWidget(
        MoonpetalApp(
          clock: FixedClock(today),
          store: SharedInMemoryAppStore(backing),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wednesday 18 November 2026'), findsOneWidget);
      expect(find.text('Today is logged'), findsOneWidget);
    },
  );

  testWidgets(
    'logged period days appear in the history oldest first',
    (tester) async {
      final store = InMemoryAppStore();
      await pumpApp(tester, store, DateTime(2026, 11, 17, 9));
      await tapLogToday(tester);

      await pumpApp(tester, store);
      await tapLogToday(tester);

      final earlier = tester.getCenter(find.text('Tuesday 17 November 2026'));
      final later = tester.getCenter(find.text('Wednesday 18 November 2026'));
      expect(earlier.dy, lessThan(later.dy));
    },
  );
}
