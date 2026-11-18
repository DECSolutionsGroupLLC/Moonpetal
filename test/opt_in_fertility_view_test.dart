import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moonpetal/app.dart';
import 'package:moonpetal/src/log_entries.dart';
import 'package:moonpetal/src/storage.dart';

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

  /// Three regular 28-day cycles, enough to derive every estimate.
  final regularStarts = <DateTime>[
    DateTime(2026, 1, 1),
    DateTime(2026, 1, 29),
    DateTime(2026, 2, 26),
  ];

  var launch = 0;

  Future<void> pumpApp(
    WidgetTester tester,
    Map<String, Object?> document, {
    DateTime? now,
    AppStore? store,
  }) async {
    await tester.pumpWidget(
      MoonpetalApp(
        key: ValueKey(launch++),
        clock: FixedClock(now ?? today),
        store: store ?? InMemoryAppStore(document: document),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> toggleFertilityView(WidgetTester tester) async {
    final toggle = find.byKey(const Key('fertilityViewSwitch'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
  }

  testWidgets('fertility view is off by default and shows no estimates', (
    tester,
  ) async {
    await pumpApp(tester, documentWithPeriodStarts(regularStarts));

    expect(find.byKey(const Key('fertilityView')), findsOneWidget);
    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const Key('fertilityViewSwitch')),
    );
    expect(toggle.value, isFalse);
    expect(find.text('Ovulation estimate'), findsNothing);
    expect(find.text('Fertile window'), findsNothing);
    expect(find.textContaining('not reliable contraception'), findsNothing);
  });

  testWidgets('opting in shows an Ovulation estimate and Fertile window, each '
      'labelled an Estimate', (tester) async {
    await pumpApp(tester, documentWithPeriodStarts(regularStarts));
    await toggleFertilityView(tester);

    expect(find.text('Ovulation estimate'), findsOneWidget);
    expect(find.text('Fertile window'), findsOneWidget);
    expect(find.byKey(const Key('estimateBadge-ovulation')), findsOneWidget);
    expect(
      find.byKey(const Key('estimateBadge-fertileWindow')),
      findsOneWidget,
    );

    final ovulation = tester.widget<Text>(
      find.byKey(const Key('ovulation-date')),
    ).data!;
    expect(
      ovulation,
      'Around ${formatLongDate(DateTime(2026, 3, 12))}',
    );

    final fertile = tester.widget<Text>(
      find.byKey(const Key('fertile-window-range')),
    ).data!;
    expect(
      fertile,
      'Between ${formatLongDate(DateTime(2026, 3, 7))} and '
      '${formatLongDate(DateTime(2026, 3, 13))}',
    );
  });

  testWidgets('the enabled view carries a permanent not-reliable-contraception '
      'notice and never marks a day safe', (tester) async {
    await pumpApp(tester, documentWithPeriodStarts(regularStarts));
    await toggleFertilityView(tester);

    final notice = find.byKey(const Key('fertilityContraceptionNotice'));
    expect(notice, findsOneWidget);
    final inCard = find.descendant(
      of: find.byKey(const Key('fertilityView')),
      matching: find.textContaining('not reliable contraception'),
    );
    expect(inCard, findsOneWidget);
    expect(
      tester.widget<Text>(find.textContaining('not reliable contraception'))
          .style
          ?.fontSize,
      isNotNull,
    );

    expect(find.textContaining('safe'), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'safe', caseSensitive: false)),
        findsNothing);
  });

  testWidgets('the opt-in state persists across a restart and can be turned '
      'off again', (tester) async {
    final store = SharedInMemoryAppStore(
      documentWithPeriodStarts(regularStarts),
    );
    await pumpApp(tester, const <String, Object?>{}, store: store);

    await toggleFertilityView(tester);
    expect(find.text('Ovulation estimate'), findsOneWidget);

    // A fresh app instance reads the same stored document.
    await pumpApp(tester, const <String, Object?>{}, store: store);
    final afterRestart = tester.widget<SwitchListTile>(
      find.byKey(const Key('fertilityViewSwitch')),
    );
    expect(afterRestart.value, isTrue);
    expect(find.text('Ovulation estimate'), findsOneWidget);

    await toggleFertilityView(tester);
    expect(find.text('Ovulation estimate'), findsNothing);

    await pumpApp(tester, const <String, Object?>{}, store: store);
    final afterTurningOff = tester.widget<SwitchListTile>(
      find.byKey(const Key('fertilityViewSwitch')),
    );
    expect(afterTurningOff.value, isFalse);
    expect(find.text('Ovulation estimate'), findsNothing);
  });

  testWidgets('the fertility estimate follows a logged period', (tester) async {
    await pumpApp(tester, documentWithPeriodStarts(regularStarts));
    await toggleFertilityView(tester);
    final before = tester.widget<Text>(
      find.byKey(const Key('ovulation-date')),
    ).data!;

    final logToday = find.text('Log today as a period day');
    await tester.ensureVisible(logToday);
    await tester.pumpAndSettle();
    await tester.tap(logToday);
    await tester.pumpAndSettle();

    final after = tester.widget<Text>(
      find.byKey(const Key('ovulation-date')),
    ).data!;
    expect(after, isNot(before));
  });

  testWidgets('enabling before there is enough history shows the notice and '
      'asks for more cycles', (tester) async {
    await pumpApp(tester, documentWithPeriodStarts(<DateTime>[
      DateTime(2026, 2, 1),
    ]));
    await toggleFertilityView(tester);

    expect(find.text('Ovulation estimate'), findsNothing);
    expect(
      find.textContaining('not reliable contraception'),
      findsOneWidget,
    );
    expect(find.textContaining('at least two cycles'), findsOneWidget);
  });

  testWidgets('the fertility view fits a phone-sized portrait viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpApp(tester, documentWithPeriodStarts(regularStarts));
    await toggleFertilityView(tester);

    final rect = tester.getRect(find.byKey(const Key('fertilityView')));
    expect(tester.takeException(), isNull);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(390));
  });
}
