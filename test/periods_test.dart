import 'package:flutter_test/flutter_test.dart';

import 'package:moonpetal/app.dart';
import 'package:moonpetal/src/log_entries.dart';
import 'package:moonpetal/src/storage.dart';

import 'helpers/fakes.dart';

void main() {
  final today = DateTime(2026, 11, 18, 9);

  Map<String, Object?> documentWithDays(Iterable<DateTime> days) => days.fold(
    <String, Object?>{},
    (document, day) => document.withPeriodDay(day),
  );

  Future<void> pumpApp(
    WidgetTester tester,
    AppStore store, [
    DateTime? now,
  ]) async {
    await tester.pumpWidget(
      MoonpetalApp(clock: FixedClock(now ?? today), store: store),
    );
    await tester.pumpAndSettle();
  }

  // The logging button may be scrolled out of view after other controls are
  // added above it, so bring it into view before tapping.
  Future<void> tapLogToday(WidgetTester tester) async {
    final finder = find.text('Log today as a period day');
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('consecutive logged period days are shown as one open period', (
    tester,
  ) async {
    final store = InMemoryAppStore(
      document: documentWithDays(<DateTime>[
        DateTime(2026, 11, 16),
        DateTime(2026, 11, 17),
        DateTime(2026, 11, 18),
      ]),
    );
    await pumpApp(tester, store);

    expect(find.text('Periods'), findsOneWidget);
    expect(find.text('Open period'), findsOneWidget);
    expect(
      find.text('Started ${formatLongDate(DateTime(2026, 11, 16))}'),
      findsOneWidget,
    );
    expect(find.text('3 days logged'), findsOneWidget);
    // An open period never guesses an end or a bleed duration.
    expect(find.textContaining('Bleed duration'), findsNothing);
  });

  testWidgets('fast-logging consecutive days keeps a single open period', (
    tester,
  ) async {
    final store = InMemoryAppStore();
    await pumpApp(tester, store, DateTime(2026, 11, 16, 9));
    await tapLogToday(tester);

    await pumpApp(tester, store, DateTime(2026, 11, 17, 9));
    await tapLogToday(tester);

    await pumpApp(tester, store, DateTime(2026, 11, 18, 9));
    await tapLogToday(tester);

    expect(find.text('Open period'), findsOneWidget);
    expect(find.text('3 days logged'), findsOneWidget);
  });

  testWidgets('a gap between logged days starts a second open period', (
    tester,
  ) async {
    final store = InMemoryAppStore(
      document: documentWithDays(<DateTime>[
        DateTime(2026, 11, 16),
        DateTime(2026, 11, 17),
        DateTime(2026, 11, 20),
      ]),
    );
    await pumpApp(tester, store);

    expect(find.text('Open period'), findsNWidgets(2));
    expect(
      find.text('Started ${formatLongDate(DateTime(2026, 11, 16))}'),
      findsOneWidget,
    );
    expect(
      find.text('Started ${formatLongDate(DateTime(2026, 11, 20))}'),
      findsOneWidget,
    );
    expect(find.text('2 days logged'), findsOneWidget);
    expect(find.text('1 day logged'), findsOneWidget);
  });

  testWidgets('the user can set an explicit period start date', (tester) async {
    final store = InMemoryAppStore();
    await pumpApp(tester, store, DateTime(2026, 11, 10, 9));

    final startButton = find.text('Set a specific start date');
    await tester.ensureVisible(startButton);
    await tester.pumpAndSettle();
    await tester.tap(startButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Open period'), findsOneWidget);
    expect(
      find.text('Started ${formatLongDate(DateTime(2026, 11, 10))}'),
      findsOneWidget,
    );
  });

  testWidgets('ending a period records and displays its bleed duration', (
    tester,
  ) async {
    final store = InMemoryAppStore(
      document: documentWithDays(<DateTime>[
        DateTime(2026, 11, 18),
        DateTime(2026, 11, 19),
        DateTime(2026, 11, 20),
      ]),
    );
    await pumpApp(tester, store);

    expect(find.text('Open period'), findsOneWidget);
    expect(find.text('Mark as ended'), findsOneWidget);

    final endButton = find.text('Mark as ended');
    await tester.ensureVisible(endButton);
    await tester.tap(endButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Open period'), findsNothing);
    expect(find.text('Mark as ended'), findsNothing);
    expect(find.text('Bleed duration: 3 days'), findsOneWidget);

    // The end date persists across a restart against the same store.
    await pumpApp(tester, store);
    expect(find.text('Bleed duration: 3 days'), findsOneWidget);
  });
}
