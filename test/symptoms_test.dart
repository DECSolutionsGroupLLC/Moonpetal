import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moonpetal/app.dart';
import 'package:moonpetal/src/log_entries.dart';
import 'package:moonpetal/src/storage.dart';

import 'helpers/fakes.dart';

void main() {
  final today = DateTime(2026, 11, 18, 9);

  Future<void> pumpApp(WidgetTester tester, AppStore store) async {
    await tester.pumpWidget(
      MoonpetalApp(clock: FixedClock(today), store: store),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapSymptom(WidgetTester tester, String name) async {
    final chip = find.widgetWithText(FilterChip, name);
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  testWidgets('one tap logs a seeded symptom and shows it in the review', (
    tester,
  ) async {
    final store = InMemoryAppStore();
    await pumpApp(tester, store);

    for (final name in ['Cramps', 'Mood', 'Energy', 'Headaches', 'Sleep']) {
      expect(find.widgetWithText(FilterChip, name), findsOneWidget);
    }

    await tapSymptom(tester, 'Cramps');

    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Cramps'))
          .selected,
      isTrue,
    );
    expect(find.text('Cramps: no severity or value'), findsOneWidget);
  });

  testWidgets('a custom symptom can be created, logged, and reused later', (
    tester,
  ) async {
    final store = InMemoryAppStore();
    await pumpApp(tester, store);

    await tester.enterText(
      find.byKey(const Key('customSymptomField')),
      'Bloating',
    );
    final addButton = find.byKey(const Key('addSymptomButton'));
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilterChip, 'Bloating'), findsOneWidget);

    await tapSymptom(tester, 'Bloating');
    expect(find.text('Bloating: no severity or value'), findsOneWidget);

    // A later launch against the same store still offers the custom name and
    // can log it again on a different day.
    await tester.pumpWidget(
      MoonpetalApp(
        clock: FixedClock(today.add(const Duration(days: 1))),
        store: store,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilterChip, 'Bloating'), findsOneWidget);
    expect(find.text('Bloating: no severity or value'), findsOneWidget);

    await tapSymptom(tester, 'Bloating');
    expect(find.text('Bloating: no severity or value'), findsNWidgets(2));
  });

  testWidgets('a logged symptom can record and change a severity or value', (
    tester,
  ) async {
    final store = InMemoryAppStore();
    await pumpApp(tester, store);
    await tapSymptom(tester, 'Cramps');

    final addDetail = find.widgetWithText(TextButton, 'Add detail');
    await tester.ensureVisible(addDetail);
    await tester.tap(addDetail);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('symptomDetailField')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('symptomDetailField')),
      'Severe',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Cramps: Severe'), findsOneWidget);
    expect(find.text('Cramps: no severity or value'), findsNothing);

    final editDetail = find.widgetWithText(TextButton, 'Edit detail');
    await tester.ensureVisible(editDetail);
    await tester.tap(editDetail);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('symptomDetailField')), 'Mild');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Cramps: Mild'), findsOneWidget);
    expect(find.text('Cramps: Severe'), findsNothing);
  });

  testWidgets('symptoms and custom names survive a fresh store', (tester) async {
    final backing = <String, Object?>{};

    await tester.pumpWidget(
      MoonpetalApp(
        clock: FixedClock(today),
        store: SharedInMemoryAppStore(backing),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('customSymptomField')),
      'Bloating',
    );
    final addButton = find.byKey(const Key('addSymptomButton'));
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    await tapSymptom(tester, 'Cramps');

    await tester.pumpWidget(
      MoonpetalApp(
        clock: FixedClock(today),
        store: SharedInMemoryAppStore(backing),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilterChip, 'Bloating'), findsOneWidget);
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Cramps'))
          .selected,
      isTrue,
    );
    expect(find.text('Cramps: no severity or value'), findsOneWidget);
  });

  testWidgets('editing a detail updates that day, not today', (tester) async {
    final yesterday = today.subtract(const Duration(days: 1));
    final store = InMemoryAppStore(
      document: <String, Object?>{}.withLoggedSymptom(yesterday, 'Cramps'),
    );
    await pumpApp(tester, store);

    final addDetail = find.widgetWithText(TextButton, 'Add detail');
    await tester.ensureVisible(addDetail);
    await tester.tap(addDetail);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('symptomDetailField')), 'Mild');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final document = await store.read();
    expect(document.symptomsFor(yesterday).single.value, 'Mild');
    expect(document.symptomsFor(today), isEmpty);
    expect(find.text('Cramps: Mild'), findsOneWidget);
  });

  testWidgets('a symptom-only day is a log entry, not a first run', (
    tester,
  ) async {
    await pumpApp(tester, InMemoryAppStore());
    expect(find.text('Welcome to Moonpetal'), findsOneWidget);

    await tapSymptom(tester, 'Sleep');

    expect(find.text('Welcome to Moonpetal'), findsNothing);
    expect(find.text('Logged symptoms'), findsOneWidget);
    expect(find.text('Sleep: no severity or value'), findsOneWidget);
  });
}
