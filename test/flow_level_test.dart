import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moonpetal/app.dart';

import 'helpers/fakes.dart';

void main() {
  final today = DateTime(2026, 11, 18, 9);

  Future<void> pumpApp(WidgetTester tester, InMemoryAppStore store) async {
    await tester.pumpWidget(
      MoonpetalApp(clock: FixedClock(today), store: store),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapFlow(WidgetTester tester, String label) async {
    final chip = find.widgetWithText(FilterChip, label);
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  testWidgets('one tap selects a flow level and shows the saved value', (
    tester,
  ) async {
    final store = InMemoryAppStore();
    await pumpApp(tester, store);

    for (final label in ['Spotting', 'Light', 'Medium', 'Heavy']) {
      expect(find.widgetWithText(FilterChip, label), findsOneWidget);
    }

    await tapFlow(tester, 'Medium');

    expect(find.text('Saved flow level: Medium'), findsOneWidget);
  });

  testWidgets('the selected flow level can be changed and cleared', (
    tester,
  ) async {
    final store = InMemoryAppStore();
    await pumpApp(tester, store);

    await tapFlow(tester, 'Light');
    expect(find.text('Saved flow level: Light'), findsOneWidget);

    await tapFlow(tester, 'Heavy');
    expect(find.text('Saved flow level: Heavy'), findsOneWidget);
    expect(find.text('Saved flow level: Light'), findsNothing);

    await tapFlow(tester, 'Heavy');
    expect(find.text('Saved flow level: Heavy'), findsNothing);
  });

  testWidgets('a saved flow level survives a restart against the same store', (
    tester,
  ) async {
    final store = InMemoryAppStore();
    await pumpApp(tester, store);
    await tapFlow(tester, 'Spotting');

    await pumpApp(tester, store);

    expect(find.text('Saved flow level: Spotting'), findsOneWidget);
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Spotting'))
          .selected,
      isTrue,
    );
  });

  testWidgets('logging a flow level does not mark the day as a period day', (
    tester,
  ) async {
    await pumpApp(tester, InMemoryAppStore());

    await tapFlow(tester, 'Light');

    expect(find.text('Saved flow level: Light'), findsOneWidget);
    expect(find.text('Log today as a period day'), findsOneWidget);
    expect(find.text('Today is logged'), findsNothing);
  });

  testWidgets("the saved flow level appears in the day's review", (
    tester,
  ) async {
    await pumpApp(tester, InMemoryAppStore());
    await tester.tap(find.text('Log today as a period day'));
    await tester.pumpAndSettle();
    await tapFlow(tester, 'Heavy');

    expect(find.text('Heavy flow'), findsOneWidget);
  });

  testWidgets('a flow level on a non-period day appears in the review', (
    tester,
  ) async {
    await pumpApp(tester, InMemoryAppStore());

    await tapFlow(tester, 'Spotting');

    expect(find.text('Spotting flow'), findsOneWidget);
  });
}
