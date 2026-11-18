import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moonpetal/app.dart';
import 'package:moonpetal/src/log_entries.dart';

import 'helpers/fakes.dart';

void main() {
  final today = DateTime(2026, 3, 10, 9);

  /// One logged day per period, so each date is a period start.
  Map<String, Object?> documentWithPeriodStarts(Iterable<DateTime> starts) {
    var document = <String, Object?>{};
    for (final start in starts) {
      document = document.withPeriodDay(start);
    }
    return document;
  }

  var launch = 0;

  Future<void> pumpApp(
    WidgetTester tester,
    Map<String, Object?> document, {
    DateTime? now,
  }) async {
    await tester.pumpWidget(
      MoonpetalApp(
        key: ValueKey(launch++),
        clock: FixedClock(now ?? today),
        store: InMemoryAppStore(document: document),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the cycle calendar shows all four phases, each marked as an '
      'Estimate', (tester) async {
    await pumpApp(
      tester,
      documentWithPeriodStarts(<DateTime>[
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 29),
        DateTime(2026, 2, 26),
      ]),
    );

    expect(find.text('Cycle calendar'), findsOneWidget);
    for (final phase in ['menstrual', 'follicular', 'ovulatory', 'luteal']) {
      final label = phase[0].toUpperCase() + phase.substring(1);
      expect(find.text(label), findsOneWidget);
      expect(find.byKey(Key('phase-estimate-$phase')), findsOneWidget);
    }
  });

  testWidgets('each phase shows an estimated date range, and the calendar '
      'says phases are estimates rather than certainties', (tester) async {
    await pumpApp(
      tester,
      documentWithPeriodStarts(<DateTime>[
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 29),
        DateTime(2026, 2, 26),
      ]),
    );

    final rangePattern = RegExp(r'\d{1,2} [A-Za-z]{3} – \d{1,2} [A-Za-z]{3}');
    for (final phase in ['menstrual', 'follicular', 'ovulatory', 'luteal']) {
      final range = tester.widget<Text>(find.byKey(Key('phase-range-$phase')));
      expect(rangePattern.hasMatch(range.data!), isTrue, reason: range.data);
    }

    expect(
      find.descendant(
        of: find.byKey(const Key('cycleCalendar')),
        matching: find.textContaining('not an exact date or medical advice'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('prediction'), findsNothing);
    expect(find.textContaining('due date'), findsNothing);
    expect(find.textContaining('safe'), findsNothing);
  });

  testWidgets('phase dates move when a period is logged', (tester) async {
    await pumpApp(
      tester,
      documentWithPeriodStarts(<DateTime>[
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 29),
        DateTime(2026, 2, 26),
      ]),
    );

    final before = displayedPhaseRange(tester, 'menstrual');

    final logToday = find.text('Log today as a period day');
    await tester.ensureVisible(logToday);
    await tester.pumpAndSettle();
    await tester.tap(logToday);
    await tester.pumpAndSettle();

    expect(displayedPhaseRange(tester, 'menstrual'), isNot(before));
  });

  testWidgets('phase dates move when a past period is corrected', (tester) async {
    final clock = SettableClock(DateTime(2026, 3, 30, 9));
    final store = InMemoryAppStore(
      document: documentWithPeriodStarts(<DateTime>[
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 29),
        DateTime(2026, 2, 26),
        DateTime(2026, 3, 26),
      ]),
    );
    await tester.pumpWidget(
      MoonpetalApp(key: ValueKey(launch++), clock: clock, store: store),
    );
    await tester.pumpAndSettle();

    final deletePastPeriod = find.byKey(const Key('delete-periodDay-2026-01-29'));
    await tester.ensureVisible(deletePastPeriod);
    await tester.pumpAndSettle();
    await tester.tap(deletePastPeriod);
    await tester.pumpAndSettle();
    final afterDeletion = displayedPhaseRange(tester, 'ovulatory');

    // Move the mistimed period's start from 29 January to 27 January. A fresh
    // launch makes the date picker use the corrected clock as its "today".
    clock.fixedNow = DateTime(2026, 1, 27, 9);
    await tester.pumpWidget(
      MoonpetalApp(key: ValueKey(launch++), clock: clock, store: store),
    );
    await tester.pumpAndSettle();
    final setStart = find.text('Set a specific start date');
    await tester.ensureVisible(setStart);
    await tester.pumpAndSettle();
    await tester.tap(setStart);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      find.text('Started ${formatLongDate(DateTime(2026, 1, 27))}'),
      findsOneWidget,
    );
    expect(displayedPhaseRange(tester, 'ovulatory'), isNot(afterDeletion));
  });

  testWidgets('the calendar shows where today sits in the estimated cycle', (
    tester,
  ) async {
    await pumpApp(
      tester,
      documentWithPeriodStarts(<DateTime>[
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 29),
        DateTime(2026, 2, 26),
      ]),
    );

    expect(find.text('Today: estimated follicular phase.'), findsOneWidget);
  });

  testWidgets('the cycle calendar fits a phone-sized portrait viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpApp(
      tester,
      documentWithPeriodStarts(<DateTime>[
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 29),
        DateTime(2026, 2, 18),
        DateTime(2026, 3, 26),
      ]),
      now: DateTime(2026, 3, 30, 9),
    );

    final rect = tester.getRect(find.byKey(const Key('cycleCalendar')));
    expect(tester.takeException(), isNull);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(390));
  });
}

String displayedPhaseRange(WidgetTester tester, String phase) =>
    tester.widget<Text>(find.byKey(Key('phase-range-$phase'))).data!;
