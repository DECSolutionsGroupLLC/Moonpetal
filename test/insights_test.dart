import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moonpetal/app.dart';
import 'package:moonpetal/src/estimate.dart';
import 'package:moonpetal/src/insights.dart';
import 'package:moonpetal/src/log_entries.dart';
import 'package:moonpetal/src/periods.dart';
import 'package:moonpetal/src/storage.dart';
import 'package:moonpetal/src/theme.dart';

import 'helpers/fakes.dart';

void main() {
  final today = DateTime(2026, 3, 10, 9);

  /// Three ended Periods with 28- and 32-day Cycles, plus logged symptoms.
  Map<String, Object?> knownDocument() {
    var document = <String, Object?>{};
    void period(DateTime start, int days) {
      for (var i = 0; i < days; i++) {
        document = document.withPeriodDay(addCalendarDays(start, i));
      }
      document = document.withPeriodEnd(
        Period(start: start),
        addCalendarDays(start, days - 1),
      );
    }

    period(DateTime(2026, 1, 1), 5);
    period(DateTime(2026, 1, 29), 4);
    period(DateTime(2026, 3, 2), 6);

    for (final day in <DateTime>[
      DateTime(2026, 1, 1),
      DateTime(2026, 1, 2),
      DateTime(2026, 1, 3),
      DateTime(2026, 1, 4),
    ]) {
      document = document.withLoggedSymptom(day, 'Cramps');
    }
    document = document.withLoggedSymptom(DateTime(2026, 1, 1), 'Mood');
    document = document.withLoggedSymptom(DateTime(2026, 1, 2), 'Mood');
    document = document.withLoggedSymptom(DateTime(2026, 3, 2), 'Headaches');
    return document;
  }

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
    AppStore? store,
  }) async {
    await tester.pumpWidget(
      MoonpetalApp(
        key: ValueKey(launch++),
        clock: FixedClock(today),
        store: store ?? InMemoryAppStore(document: document),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openInsights(WidgetTester tester) async {
    final button = find.byKey(const Key('viewInsightsButton'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Finder summary(Key key) => find.byKey(key);

  testWidgets('the insights screen shows all four summaries beside their '
      'charts, matched to known log entries', (tester) async {
    await pumpApp(tester, knownDocument());
    await openInsights(tester);

    expect(find.text('Insights'), findsOneWidget);
    for (final card in <String>[
      'insight-cycleLength',
      'insight-bleedDuration',
      'insight-symptoms',
      'insight-variability',
    ]) {
      expect(find.byKey(Key(card)), findsOneWidget);
    }

    expect(
      tester.widget<Text>(summary(const Key('insight-cycleLength-summary'))).data,
      'Your Cycle length averaged about 30 days across the 2 cycles you logged.',
    );
    expect(
      tester.widget<Text>(summary(const Key('insight-bleedDuration-summary'))).data,
      'Your periods lasted about 5 days on average across the 3 periods you '
      'ended.',
    );
    expect(
      tester.widget<Text>(summary(const Key('insight-symptoms-summary'))).data,
      'You logged Cramps on 4 days, more than any other symptom. You also '
      'logged Mood on 2 days, Headaches on 1 day.',
    );
    expect(
      tester.widget<Text>(summary(const Key('insight-variability-summary'))).data,
      'Your Cycle lengths ranged from 28 to 32 days, a spread of 4 days. That '
      'is why your next-period Estimate is shown as a range rather than one '
      'day.',
    );
  });

  testWidgets('every chart carries an adjacent plain-language sentence with '
      'readable contrast and no medical claims', (tester) async {
    await pumpApp(tester, knownDocument());
    await openInsights(tester);

    final summaries = <Key>[
      const Key('insight-cycleLength-summary'),
      const Key('insight-bleedDuration-summary'),
      const Key('insight-symptoms-summary'),
      const Key('insight-variability-summary'),
    ];
    for (final key in summaries) {
      final finder = find.byKey(key);
      expect(finder, findsOneWidget);

      final text = tester.widget<Text>(finder);
      expect(text.data, isNotEmpty);
      expect(text.style?.fontSize, greaterThanOrEqualTo(16));
      expect(text.style?.color, MoonpetalColors.deepPink);

      // Each sentence lives inside the same card as its chart.
      final card = find.ancestor(
        of: finder,
        matching: find.byType(Card),
      );
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.byKey(key)),
        findsOneWidget,
      );

      final words = text.data!.toLowerCase();
      for (final claim in <String>[
        'diagnose',
        'treatment',
        'you have',
        'normal',
        'abnormal',
        'healthy',
      ]) {
        expect(words.contains(claim), isFalse, reason: 'found "$claim"');
      }
    }

    expect(find.byKey(const Key('insightsNotMedicalAdvice')), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const Key('insightsNotMedicalAdvice')),
              matching: find.byType(Text),
            ),
          )
          .data,
      insightsNotMedicalAdvice,
    );
  });

  testWidgets('insufficient history gives honest empty sentences instead of '
      'invented numbers', (tester) async {
    await pumpApp(
      tester,
      documentWithPeriodStarts(<DateTime>[DateTime(2026, 2, 1)]),
    );
    await openInsights(tester);

    expect(
      find.text('Log at least two period starts to see your average Cycle '
          'length.'),
      findsOneWidget,
    );
    expect(
      find.text('Mark a period as ended to see your average Bleed duration.'),
      findsOneWidget,
    );
    expect(
      find.text('Log a symptom to see which ones come up most often.'),
      findsOneWidget,
    );
    expect(
      find.text('Log a few Cycles to see how much your Cycle lengths vary.'),
      findsOneWidget,
    );
  });

  testWidgets('the insights screen reflects newly logged data', (tester) async {
    final store = SharedInMemoryAppStore(knownDocument());
    await pumpApp(tester, const <String, Object?>{}, store: store);
    await openInsights(tester);
    final before = tester.widget<Text>(
      find.byKey(const Key('insight-symptoms-summary')),
    ).data;

    // Add one more Cramps day, then relaunch against the shared on-device data.
    final updated = <String, Object?>{...store.backing};
    final withSymptom = updated.withLoggedSymptom(DateTime(2026, 3, 3), 'Cramps');
    await pumpApp(
      tester,
      const <String, Object?>{},
      store: SharedInMemoryAppStore(withSymptom),
    );
    await openInsights(tester);
    final after = tester.widget<Text>(
      find.byKey(const Key('insight-symptoms-summary')),
    ).data;

    expect(before, contains('Cramps on 4 days'));
    expect(after, contains('Cramps on 5 days'));
    expect(after, isNot(before));
  });

  testWidgets('the insights screen fits a phone-sized portrait viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpApp(tester, knownDocument());
    await openInsights(tester);

    final summaryRect = tester.getRect(
      find.byKey(const Key('insight-symptoms-summary')),
    );
    expect(tester.takeException(), isNull);
    expect(summaryRect.left, greaterThanOrEqualTo(0));
    expect(summaryRect.right, lessThanOrEqualTo(390));
  });
}
