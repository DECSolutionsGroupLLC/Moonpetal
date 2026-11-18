import 'package:flutter_test/flutter_test.dart';

import 'package:moonpetal/src/log_entries.dart';
import 'package:moonpetal/src/storage.dart';

void main() {
  final day = DateTime(2026, 11, 18);

  test('a note can be written, edited and cleared on a day', () {
    final written = <String, Object?>{}.withNote(day, 'Felt great today');
    expect(written.noteFor(day), 'Felt great today');

    final edited = written.withNote(day, 'Actually quite tired');
    expect(edited.noteFor(day), 'Actually quite tired');

    final cleared = edited.withNote(day, null);
    expect(cleared.noteFor(day), isNull);
  });

  test('a blank note clears it rather than storing whitespace', () {
    final document = <String, Object?>{}
        .withNote(day, 'A note')
        .withNote(day, '   ');

    expect(document.noteFor(day), isNull);
    final stored = (document[logEntriesKey] as List).single
        as Map<String, Object?>;
    expect(stored.containsKey(noteKey), isFalse);
  });

  test('writing a note keeps the period day, flow level and symptoms', () {
    final document = <String, Object?>{}
        .withPeriodDay(day)
        .withFlowLevel(day, FlowLevel.medium)
        .withLoggedSymptom(day, 'Cramps');

    final updated = document.withNote(day, 'Cramps eased by evening');

    final entry = updated.logEntries.forDay(day)!;
    expect(entry.isPeriodDay, isTrue);
    expect(entry.flowLevel, FlowLevel.medium);
    expect(entry.symptoms.single.name, 'Cramps');
    expect(entry.note, 'Cramps eased by evening');
    expect(updated.tagsFor(day), isEmpty);
  });

  test('a tag can be created, attached to a day, and removed again', () {
    final created = <String, Object?>{}.withTagName('  doctor  ');
    expect(created.tagNames, equals(['doctor']));

    final attached = created.withToggledTag(day, 'doctor');
    expect(attached.tagsFor(day), equals(['doctor']));

    final removed = attached.withToggledTag(day, 'doctor');
    expect(removed.tagsFor(day), isEmpty);
    expect(removed.tagNames, equals(['doctor']));
  });

  test('created tag names are trimmed and deduplicated', () {
    final document = <String, Object?>{}
        .withTagName('todo')
        .withTagName('  later  ')
        .withTagName('todo')
        .withTagName('   ');

    expect(document.tagNames, equals(['todo', 'later']));
    expect(document[tagNamesKey], equals(['todo', 'later']));
  });

  test('tags and symptoms stay separate in the stored data', () {
    final tagged = <String, Object?>{}
        .withToggledTag(day, 'todo')
        .withNote(day, 'A note');
    final storedTagEntry = (tagged[logEntriesKey] as List).single
        as Map<String, Object?>;
    expect(storedTagEntry.containsKey(tagsKey), isTrue);
    expect(storedTagEntry.containsKey(symptomsKey), isFalse);

    final withSymptom = tagged.withLoggedSymptom(day, 'todo');
    expect(withSymptom.tagsFor(day), equals(['todo']));
    expect(withSymptom.symptomsFor(day).single.name, 'todo');
    final storedBoth = (withSymptom[logEntriesKey] as List).single
        as Map<String, Object?>;
    expect(storedBoth[tagsKey], equals(['todo']));
    expect((storedBoth[symptomsKey] as List).single,
        containsPair('name', 'todo'));

    final untagged = withSymptom.withoutTag(day, 'todo');
    expect(untagged.tagsFor(day), isEmpty);
    expect(untagged.symptomsFor(day).single.name, 'todo');
  });

  test('only days with an attached tag appear in the tag review', () {
    final document = <String, Object?>{}
        .withToggledTag(day, 'todo')
        .withPeriodDay(day.add(const Duration(days: 1)));

    expect(document.tagDays, hasLength(1));
    expect(document.tagDays.single.dayKey, '2026-11-18');
  });
}
