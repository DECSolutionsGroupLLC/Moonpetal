import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moonpetal/app.dart';
import 'package:moonpetal/src/log_entries.dart';
import 'package:moonpetal/src/periods.dart';
import 'package:moonpetal/src/storage.dart';

import 'helpers/fakes.dart';

void main() {
  final today = DateTime(2026, 3, 10, 9);

  Map<String, Object?> documentWithPeriods() {
    var document = <String, Object?>{};
    for (final day in <DateTime>[
      DateTime(2026, 1, 1),
      DateTime(2026, 1, 2),
      DateTime(2026, 1, 3),
      DateTime(2026, 1, 4),
      DateTime(2026, 1, 5),
      DateTime(2026, 1, 29),
      DateTime(2026, 1, 30),
      DateTime(2026, 1, 31),
      DateTime(2026, 2, 1),
      DateTime(2026, 2, 24),
      DateTime(2026, 2, 25),
    ]) {
      document = document.withPeriodDay(day);
    }
    document = document.withPeriodEnd(
      Period(start: DateTime(2026, 1, 1)),
      DateTime(2026, 1, 5),
    );
    return document.withPeriodEnd(
      Period(start: DateTime(2026, 1, 29)),
      DateTime(2026, 2, 1),
    );
  }

  Future<void> pumpApp(WidgetTester tester, AppStore store) async {
    await tester.pumpWidget(
      MoonpetalApp(clock: FixedClock(today), store: store),
    );
    await tester.pumpAndSettle();
  }

  Finder cycleCard(DateTime start) => find.ancestor(
    of: find.text('Cycle starting ${formatLongDate(start)}'),
    matching: find.byType(Card),
  );

  testWidgets('cycle history shows labelled cycle length and bleed duration', (
    tester,
  ) async {
    await pumpApp(tester, InMemoryAppStore(document: documentWithPeriods()));

    expect(find.text('Cycle history'), findsOneWidget);
    expect(
      find.text(
        'Cycle length counts the days from one period start to the next '
        'period start.',
      ),
      findsOneWidget,
    );

    final first = cycleCard(DateTime(2026, 1, 1));
    expect(
      find.descendant(of: first, matching: find.text('Cycle length: 28 days')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: first,
        matching: find.text('Bleed duration: 5 days'),
      ),
      findsOneWidget,
    );

    final second = cycleCard(DateTime(2026, 1, 29));
    expect(
      find.descendant(of: second, matching: find.text('Cycle length: 26 days')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: second,
        matching: find.text('Bleed duration: 4 days'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('regular cycles show the same count for each previous cycle', (
    tester,
  ) async {
    var document = <String, Object?>{};
    for (final day in <DateTime>[
      DateTime(2026, 1, 1),
      DateTime(2026, 1, 29),
      DateTime(2026, 2, 26),
    ]) {
      document = document.withPeriodDay(day);
    }

    await pumpApp(tester, InMemoryAppStore(document: document));

    // Both completed cycles are 28 days start-to-start under the fixed clock.
    expect(find.text('Cycle length: 28 days'), findsNWidgets(2));
  });

  testWidgets('irregular cycles show each start-to-start count', (tester) async {
    await pumpApp(tester, InMemoryAppStore(document: documentWithPeriods()));

    // Jan 1 -> Jan 29 is 28 days; Jan 29 -> Feb 24 is 26 days.
    expect(find.text('Cycle length: 28 days'), findsOneWidget);
    expect(find.text('Cycle length: 26 days'), findsOneWidget);
  });

  testWidgets('only completed cycles appear in the history', (tester) async {
    await pumpApp(tester, InMemoryAppStore(document: documentWithPeriods()));

    // Three periods means two completed cycles; the latest open period has no
    // next start yet and so no cycle length of its own.
    expect(find.textContaining('Cycle length:'), findsNWidgets(2));
    expect(
      find.text('Cycle starting ${formatLongDate(DateTime(2026, 2, 24))}'),
      findsNothing,
    );
  });

  testWidgets('an open starting period shows bleed duration not recorded', (
    tester,
  ) async {
    final document = <String, Object?>{}
        .withPeriodDay(DateTime(2026, 1, 1))
        .withPeriodDay(DateTime(2026, 1, 29));

    await pumpApp(tester, InMemoryAppStore(document: document));

    expect(find.text('Cycle length: 28 days'), findsOneWidget);
    expect(find.text('Bleed duration: not recorded'), findsOneWidget);
  });
}
