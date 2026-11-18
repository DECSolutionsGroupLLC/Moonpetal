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

  testWidgets('the user can write and edit a free-text note on today', (
    tester,
  ) async {
    final store = InMemoryAppStore();
    await pumpApp(tester, store);

    final noteField = find.byKey(const Key('noteField'));
    await tester.ensureVisible(noteField);
    await tester.enterText(noteField, 'Felt great today');
    await tester.tap(find.byKey(const Key('saveNoteButton')));
    await tester.pumpAndSettle();

    expect(find.text('Notes'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Felt great today'), findsOneWidget);

    await tester.ensureVisible(noteField);
    await tester.enterText(noteField, 'Actually quite tired');
    await tester.tap(find.byKey(const Key('saveNoteButton')));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(ListTile, 'Actually quite tired'),
      findsOneWidget,
    );
    expect(find.widgetWithText(ListTile, 'Felt great today'), findsNothing);

    final document = await store.read();
    expect(document.noteFor(today), 'Actually quite tired');
  });

  Future<void> createTag(WidgetTester tester, String name) async {
    await tester.enterText(find.byKey(const Key('customTagField')), name);
    final add = find.byKey(const Key('addTagButton'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
  }

  Future<void> tapTagChip(WidgetTester tester, String name) async {
    final chip = find.widgetWithText(FilterChip, name);
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  testWidgets('a tag can be created, attached to today, and removed', (
    tester,
  ) async {
    final store = InMemoryAppStore();
    await pumpApp(tester, store);

    await createTag(tester, 'travel');
    final chip = find.widgetWithText(FilterChip, 'travel');
    expect(chip, findsOneWidget);

    await tapTagChip(tester, 'travel');
    expect(tester.widget<FilterChip>(chip).selected, isTrue);
    expect(find.text('Logged tags'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'travel'), findsOneWidget);

    await tapTagChip(tester, 'travel');
    expect(tester.widget<FilterChip>(chip).selected, isFalse);
    expect(find.widgetWithText(ListTile, 'travel'), findsNothing);

    final document = await store.read();
    expect(document.tagsFor(today), isEmpty);
    expect(document.tagNames, equals(['travel']));
  });

  testWidgets('tags appear in the review and persist across a restart', (
    tester,
  ) async {
    final backing = <String, Object?>{};

    await tester.pumpWidget(
      MoonpetalApp(
        clock: FixedClock(today),
        store: SharedInMemoryAppStore(backing),
      ),
    );
    await tester.pumpAndSettle();

    await createTag(tester, 'todo');
    await tapTagChip(tester, 'todo');

    await tester.pumpWidget(
      MoonpetalApp(
        clock: FixedClock(today),
        store: SharedInMemoryAppStore(backing),
      ),
    );
    await tester.pumpAndSettle();

    final chip = find.widgetWithText(FilterChip, 'todo');
    expect(chip, findsOneWidget);
    expect(tester.widget<FilterChip>(chip).selected, isTrue);
    expect(find.widgetWithText(ListTile, 'todo'), findsOneWidget);
  });

  testWidgets('tags are presented separately from symptoms', (tester) async {
    final store = InMemoryAppStore();
    await pumpApp(tester, store);

    await tapTagChip(tester, 'Cramps');
    var document = await store.read();
    var entry = (document[logEntriesKey] as List).single
        as Map<String, Object?>;
    expect(entry.containsKey(tagsKey), isFalse);

    await createTag(tester, 'todo');
    await tapTagChip(tester, 'todo');

    expect(find.text('Symptoms'), findsOneWidget);
    expect(find.text('Tags'), findsOneWidget);
    expect(find.text('Logged symptoms'), findsOneWidget);
    expect(find.text('Logged tags'), findsOneWidget);
    expect(find.text('Cramps: no severity or value'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'todo'), findsOneWidget);
    expect(find.text('todo: no severity or value'), findsNothing);

    document = await store.read();
    entry = (document[logEntriesKey] as List).single as Map<String, Object?>;
    expect(entry[tagsKey], equals(['todo']));
    expect((entry[symptomsKey] as List).single, containsPair('name', 'Cramps'));
  });
}
