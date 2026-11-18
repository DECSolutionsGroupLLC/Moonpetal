import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moonpetal/app.dart';
import 'package:moonpetal/src/log_entries.dart';

import 'helpers/fakes.dart';

void main() {
  const dayKey = '2026-11-18';

  testWidgets('a corrected note shows its prior value and timestamps, and '
      'both survive a restart', (tester) async {
    final backing = <String, Object?>{};
    final clock = SettableClock(DateTime(2026, 11, 18, 8, 30));
    var launch = 0;

    Future<void> pumpApp() async {
      await tester.pumpWidget(
        MoonpetalApp(
          key: ValueKey(launch++),
          clock: clock,
          store: SharedInMemoryAppStore(backing),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpApp();
    final noteField = find.byKey(const Key('noteField'));
    await tester.ensureVisible(noteField);
    await tester.enterText(noteField, 'Felt great');
    await tester.tap(find.byKey(const Key('saveNoteButton')));
    await tester.pumpAndSettle();

    clock.fixedNow = DateTime(2026, 11, 18, 9, 15);
    final edit = find.byKey(const Key('edit-note-$dayKey'));
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('correctionField')),
      'Actually tired',
    );
    await tester.tap(find.byKey(const Key('saveCorrection')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Actually tired'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Felt great'), findsNothing);

    final history = find.byKey(const Key('history-note-$dayKey'));
    await tester.ensureVisible(history);
    await tester.pumpAndSettle();
    await tester.tap(history);
    await tester.pumpAndSettle();

    final dialog = find.byKey(const Key('historyDialog'));
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.textContaining('Felt great')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining('Actually tired'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining('18 Nov 2026, 08:30'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining('18 Nov 2026, 09:15'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await pumpApp();

    expect(find.widgetWithText(ListTile, 'Actually tired'), findsOneWidget);
    final historyAfterRestart = find.byKey(const Key('history-note-$dayKey'));
    await tester.ensureVisible(historyAfterRestart);
    await tester.pumpAndSettle();
    await tester.tap(historyAfterRestart);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('historyDialog')),
        matching: find.textContaining('Felt great'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a past flow level can be corrected and deleted from its '
      'review row', (tester) async {
    final store = InMemoryAppStore();
    final clock = SettableClock(DateTime(2026, 11, 18, 8, 30));
    await tester.pumpWidget(
      MoonpetalApp(clock: clock, store: store),
    );
    await tester.pumpAndSettle();

    final light = find.widgetWithText(FilterChip, 'Light');
    await tester.ensureVisible(light);
    await tester.pumpAndSettle();
    await tester.tap(light);
    await tester.pumpAndSettle();
    expect(find.text('Light flow'), findsOneWidget);

    clock.fixedNow = DateTime(2026, 11, 18, 9, 15);
    final edit = find.byKey(const Key('edit-flowLevel-$dayKey'));
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('correction-flow-heavy')));
    await tester.pumpAndSettle();

    expect(find.text('Heavy flow'), findsOneWidget);
    expect(find.text('Light flow'), findsNothing);

    final history = find.byKey(const Key('history-flowLevel-$dayKey'));
    await tester.ensureVisible(history);
    await tester.pumpAndSettle();
    await tester.tap(history);
    await tester.pumpAndSettle();
    final dialog = find.byKey(const Key('historyDialog'));
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining('Light flow — 18 Nov 2026, 08:30'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining('Heavy flow — 18 Nov 2026, 09:15'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    final editAgain = find.byKey(const Key('edit-flowLevel-$dayKey'));
    await tester.ensureVisible(editAgain);
    await tester.pumpAndSettle();
    await tester.tap(editAgain);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deleteCorrection')));
    await tester.pumpAndSettle();

    expect(find.text('Heavy flow'), findsNothing);
    final document = await store.read();
    expect(document.flowLevelFor(DateTime(2026, 11, 18)), isNull);
    expect(
      document.editHistoryFor(DateTime(2026, 11, 18), flowLevelKey).last.value,
      isNull,
    );
  });

  testWidgets('a past symptom can be corrected and removed from its review '
      'row', (tester) async {
    final store = InMemoryAppStore();
    final clock = SettableClock(DateTime(2026, 11, 18, 8, 30));
    await tester.pumpWidget(
      MoonpetalApp(clock: clock, store: store),
    );
    await tester.pumpAndSettle();

    final crampsChip = find.widgetWithText(FilterChip, 'Cramps');
    await tester.ensureVisible(crampsChip);
    await tester.pumpAndSettle();
    await tester.tap(crampsChip);
    await tester.pumpAndSettle();

    final addDetail = find.widgetWithText(TextButton, 'Add detail');
    await tester.ensureVisible(addDetail);
    await tester.pumpAndSettle();
    await tester.tap(addDetail);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('symptomDetailField')),
      'Mild',
    );
    await tester.tap(find.byKey(const Key('saveCorrection')));
    await tester.pumpAndSettle();
    expect(find.text('Cramps: Mild'), findsOneWidget);

    clock.fixedNow = DateTime(2026, 11, 18, 9, 15);
    final edit = find.byKey(const Key('edit-symptom:Cramps-$dayKey'));
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('symptomDetailField')),
      'Severe',
    );
    await tester.tap(find.byKey(const Key('saveCorrection')));
    await tester.pumpAndSettle();

    expect(find.text('Cramps: Severe'), findsOneWidget);
    expect(find.text('Cramps: Mild'), findsNothing);

    final history = find.byKey(const Key('history-symptom:Cramps-$dayKey'));
    await tester.ensureVisible(history);
    await tester.pumpAndSettle();
    await tester.tap(history);
    await tester.pumpAndSettle();
    final dialog = find.byKey(const Key('historyDialog'));
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining('Cramps: Mild — 18 Nov 2026, 08:30'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining('Cramps: Severe — 18 Nov 2026, 09:15'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    final editAgain = find.byKey(const Key('edit-symptom:Cramps-$dayKey'));
    await tester.ensureVisible(editAgain);
    await tester.pumpAndSettle();
    await tester.tap(editAgain);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deleteCorrection')));
    await tester.pumpAndSettle();

    final document = await store.read();
    expect(document.symptomsFor(DateTime(2026, 11, 18)), isEmpty);
    expect(
      document
          .editHistoryFor(
            DateTime(2026, 11, 18),
            symptomHistoryField('Cramps'),
          )
          .last
          .value,
      isNull,
    );
  });

  testWidgets('a tag can be corrected and a period-day mark removed, with '
      'both changes kept in history', (tester) async {
    final store = InMemoryAppStore();
    final clock = SettableClock(DateTime(2026, 11, 18, 8, 30));
    await tester.pumpWidget(
      MoonpetalApp(clock: clock, store: store),
    );
    await tester.pumpAndSettle();

    final tagField = find.byKey(const Key('customTagField'));
    await tester.ensureVisible(tagField);
    await tester.pumpAndSettle();
    await tester.enterText(tagField, 'todo');
    final addTag = find.byKey(const Key('addTagButton'));
    await tester.ensureVisible(addTag);
    await tester.pumpAndSettle();
    await tester.tap(addTag);
    await tester.pumpAndSettle();
    final tagChip = find.widgetWithText(FilterChip, 'todo');
    await tester.ensureVisible(tagChip);
    await tester.pumpAndSettle();
    await tester.tap(tagChip);
    await tester.pumpAndSettle();
    final logPeriodDay = find.text('Log today as a period day');
    await tester.ensureVisible(logPeriodDay);
    await tester.pumpAndSettle();
    await tester.tap(logPeriodDay);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'todo'), findsOneWidget);
    expect(find.text('Period day'), findsOneWidget);

    clock.fixedNow = DateTime(2026, 11, 18, 9, 15);
    final editTag = find.byKey(const Key('edit-tag:todo-$dayKey'));
    await tester.ensureVisible(editTag);
    await tester.pumpAndSettle();
    await tester.tap(editTag);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('correctionField')),
      'done',
    );
    await tester.tap(find.byKey(const Key('saveCorrection')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'todo'), findsNothing);
    expect(find.widgetWithText(ListTile, 'done'), findsOneWidget);

    final tagHistory = find.byKey(const Key('history-tag:done-$dayKey'));
    await tester.ensureVisible(tagHistory);
    await tester.pumpAndSettle();
    await tester.tap(tagHistory);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('historyDialog')),
        matching: find.textContaining('Tag todo removed — 18 Nov 2026, 09:15'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('historyDialog')),
        matching: find.textContaining('Tag done added — 18 Nov 2026, 09:15'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    final removePeriodDay = find.byKey(const Key('delete-periodDay-$dayKey'));
    await tester.ensureVisible(removePeriodDay);
    await tester.pumpAndSettle();
    await tester.tap(removePeriodDay);
    await tester.pumpAndSettle();

    final document = await store.read();
    expect(document.periodDays.containsDay(DateTime(2026, 11, 18)), isFalse);
    expect(
      document
          .editHistoryFor(DateTime(2026, 11, 18), periodDayKey)
          .map((record) => record.value),
      equals([true, null]),
    );
  });

  testWidgets('history marks each field current, and can delete the whole '
      'entry', (tester) async {
    final store = InMemoryAppStore();
    final clock = SettableClock(DateTime(2026, 11, 18, 8, 30));
    await tester.pumpWidget(
      MoonpetalApp(clock: clock, store: store),
    );
    await tester.pumpAndSettle();

    final light = find.widgetWithText(FilterChip, 'Light');
    await tester.ensureVisible(light);
    await tester.pumpAndSettle();
    await tester.tap(light);
    await tester.pumpAndSettle();

    clock.fixedNow = DateTime(2026, 11, 18, 9, 15);
    final noteField = find.byKey(const Key('noteField'));
    await tester.ensureVisible(noteField);
    await tester.pumpAndSettle();
    await tester.enterText(noteField, 'A note');
    await tester.tap(find.byKey(const Key('saveNoteButton')));
    await tester.pumpAndSettle();

    final history = find.byKey(const Key('history-flowLevel-$dayKey'));
    await tester.ensureVisible(history);
    await tester.pumpAndSettle();
    await tester.tap(history);
    await tester.pumpAndSettle();

    final dialog = find.byKey(const Key('historyDialog'));
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining('Light flow — 18 Nov 2026, 08:30 (current)'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining('Note: A note — 18 Nov 2026, 09:15 (current)'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('deleteEntryButton')));
    await tester.pumpAndSettle();

    expect(find.text('Light flow'), findsNothing);
    expect(find.text('A note'), findsNothing);
    final document = await store.read();
    final day = DateTime(2026, 11, 18);
    expect(document.logEntries.forDay(day), isNotNull);
    expect(document.flowLevelFor(day), isNull);
    expect(document.noteFor(day), isNull);
    expect(document.editHistoryForDay(day), hasLength(4));
  });
}
