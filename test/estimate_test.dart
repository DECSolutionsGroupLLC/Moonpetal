import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

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

  /// Scopes wording assertions to the next-period card: the cycle calendar
  /// also presents labelled estimates and the same "not exact" assurance.
  Finder inNextPeriodCard(Finder finder) => find.descendant(
    of: find.byKey(const Key('nextPeriodEstimate')),
    matching: finder,
  );

  int displayedWindowDays(WidgetTester tester) {
    final text = tester.widget<Text>(
      find.textContaining('This window spans about'),
    ).data!;
    return int.parse(RegExp(r'about (\d+) days').firstMatch(text)!.group(1)!);
  }

  DateTime displayedAroundDate(WidgetTester tester) {
    final text = tester.widget<Text>(find.textContaining('Around ')).data!;
    return DateFormat('EEEE d MMMM y').parse(text.substring('Around '.length));
  }

  String displayedRangeText(WidgetTester tester) =>
      tester.widget<Text>(find.textContaining('Between ')).data!;

  testWidgets('two cycles show a labelled next-period Estimate with a date '
      'and a visible range', (tester) async {
    await pumpApp(
      tester,
      documentWithPeriodStarts(<DateTime>[
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 29),
        DateTime(2026, 2, 26),
      ]),
    );

    expect(find.text('Next period Estimate'), findsOneWidget);
    expect(inNextPeriodCard(find.text('Estimate')), findsOneWidget);
    expect(
      find.text('Around ${formatLongDate(DateTime(2026, 3, 26))}'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Between ${formatLongDate(DateTime(2026, 3, 25))} and '
        '${formatLongDate(DateTime(2026, 3, 27))}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Estimate wording makes no promise of a precise date', (
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

    expect(
      inNextPeriodCard(find.textContaining('not an exact date')),
      findsOneWidget,
    );
    expect(find.textContaining('due date'), findsNothing);
    expect(find.textContaining('prediction'), findsNothing);
    expect(find.textContaining('exactly'), findsNothing);
  });

  testWidgets('the Estimate range widens when cycle lengths vary, and the '
      'explanation says why', (tester) async {
    final afterLastStart = DateTime(2026, 3, 30, 9);

    // Three regular 28-day cycles, ending at the 26 February start.
    await pumpApp(
      tester,
      documentWithPeriodStarts(<DateTime>[
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 29),
        DateTime(2026, 2, 26),
        DateTime(2026, 3, 26),
      ]),
      now: afterLastStart,
    );
    final regularWindow = displayedWindowDays(tester);
    final regularRangeText = displayedRangeText(tester);
    expect(find.textContaining('fairly regular'), findsOneWidget);
    expect(
      inNextPeriodCard(find.textContaining('not an exact date')),
      findsOneWidget,
    );

    // Same number of cycles and the same latest start, but 28/20/36 days.
    await pumpApp(
      tester,
      documentWithPeriodStarts(<DateTime>[
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 29),
        DateTime(2026, 2, 18),
        DateTime(2026, 3, 26),
      ]),
      now: afterLastStart,
    );
    final variedWindow = displayedWindowDays(tester);
    expect(variedWindow, greaterThan(regularWindow));
    expect(displayedRangeText(tester), isNot(regularRangeText));
    expect(find.textContaining('varied'), findsOneWidget);
    expect(
      inNextPeriodCard(find.textContaining('not an exact date')),
      findsOneWidget,
    );
  });

  testWidgets('recent cycles count for more than older ones', (tester) async {
    final now = DateTime(2026, 4, 5, 9);

    // Same three lengths (28/28/35) and the same latest start in both cases;
    // only which cycles are newest changes.
    await pumpApp(
      tester,
      documentWithPeriodStarts(<DateTime>[
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 29),
        DateTime(2026, 2, 26),
        DateTime(2026, 4, 2),
      ]),
      now: now,
    );
    final longerCyclesMostRecent = displayedAroundDate(tester);
    expect(find.textContaining('latest counting more'), findsOneWidget);

    await pumpApp(
      tester,
      documentWithPeriodStarts(<DateTime>[
        DateTime(2026, 1, 1),
        DateTime(2026, 2, 5),
        DateTime(2026, 3, 5),
        DateTime(2026, 4, 2),
      ]),
      now: now,
    );
    final longerCyclesOldest = displayedAroundDate(tester);

    expect(longerCyclesMostRecent.isAfter(longerCyclesOldest), isTrue);
  });

  testWidgets('deleting a past period recomputes the Estimate', (tester) async {
    final document = documentWithPeriodStarts(<DateTime>[
      DateTime(2026, 1, 1),
      DateTime(2026, 1, 29),
      DateTime(2026, 2, 26),
      DateTime(2026, 3, 26),
    ]);
    await pumpApp(
      tester,
      document,
      now: DateTime(2026, 3, 30, 9),
    );

    final before = displayedAroundDate(tester);
    final beforeRange = displayedRangeText(tester);

    final deletePastPeriod = find.byKey(const Key('delete-periodDay-2026-01-29'));
    await tester.ensureVisible(deletePastPeriod);
    await tester.pumpAndSettle();
    await tester.tap(deletePastPeriod);
    await tester.pumpAndSettle();

    final after = displayedAroundDate(tester);
    expect(after.isAfter(before), isTrue);
    expect(displayedRangeText(tester), isNot(beforeRange));
  });

  testWidgets('correcting a past period start recomputes the Estimate', (
    tester,
  ) async {
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
    final afterDeletion = displayedAroundDate(tester);

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
    expect(displayedAroundDate(tester), isNot(afterDeletion));
  });

  testWidgets('the Estimate stays ahead of the user when periods are old', (
    tester,
  ) async {
    final now = DateTime(2026, 12, 1, 9);
    await pumpApp(
      tester,
      documentWithPeriodStarts(<DateTime>[
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 29),
        DateTime(2026, 2, 26),
      ]),
      now: now,
    );

    expect(displayedAroundDate(tester).isAfter(now), isTrue);
  });

  testWidgets('the Estimate fits a phone-sized portrait viewport', (
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

    final range = tester.getRect(find.textContaining('Between '));
    expect(tester.takeException(), isNull);
    expect(range.left, greaterThanOrEqualTo(0));
    expect(range.right, lessThanOrEqualTo(390));
  });
}
