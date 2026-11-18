import 'package:flutter_test/flutter_test.dart';

import 'package:moonpetal/src/log_entries.dart';
import 'package:moonpetal/src/storage.dart';

void main() {
  final day = DateTime(2026, 11, 18);

  test('seeded symptoms are offered before any custom names', () {
    expect(
      <String, Object?>{}.availableSymptomNames,
      equals(seededSymptomNames),
    );
  });

  test('logging a symptom keeps the period day, flow level and other entries', () {
    final document = <String, Object?>{
      logEntriesKey: <Object?>['an entry from a later slice'],
    }.withPeriodDay(day).withFlowLevel(day, FlowLevel.light);

    final updated = document.withLoggedSymptom(day, 'Cramps', value: 'Mild');

    expect(updated[logEntriesKey], contains('an entry from a later slice'));
    final entry = updated.logEntries.forDay(day)!;
    expect(entry.isPeriodDay, isTrue);
    expect(entry.flowLevel, FlowLevel.light);
    expect(entry.symptoms.single.name, 'Cramps');
    expect(entry.symptoms.single.value, 'Mild');
  });

  test('toggling a symptom logs it once, then removes it', () {
    final logged = <String, Object?>{}.withToggledSymptom(day, 'Mood');
    expect(logged.symptomsFor(day).single.name, 'Mood');

    final removed = logged.withToggledSymptom(day, 'Mood');
    expect(removed.symptomsFor(day), isEmpty);
  });

  test('logging the same symptom again updates its value, not the entry', () {
    final updated = <String, Object?>{}
        .withLoggedSymptom(day, 'Mood', value: 'Low')
        .withLoggedSymptom(day, 'Mood', value: 'Good');

    expect(updated.symptomsFor(day), hasLength(1));
    expect(updated.symptomsFor(day).single.value, 'Good');
  });

  test('clearing a value keeps the symptom; removing it keeps the rest', () {
    final logged = <String, Object?>{}
        .withLoggedSymptom(day, 'Cramps', value: 'Mild')
        .withPeriodDay(day);

    final cleared = logged.withLoggedSymptom(day, 'Cramps', value: null);
    expect(cleared.symptomsFor(day).single.value, isNull);
    expect(cleared.logEntries.forDay(day)!.isPeriodDay, isTrue);

    final removed = cleared.withoutLoggedSymptom(day, 'Cramps');
    expect(removed.symptomsFor(day), isEmpty);
    expect(removed.logEntries.forDay(day)!.isPeriodDay, isTrue);
  });

  test('custom names are trimmed, deduplicated and kept out of log entries', () {
    final added = <String, Object?>{}.withCustomSymptomName('  Bloating  ');

    expect(added.customSymptomNames, equals(['Bloating']));
    expect(added[symptomNamesKey], equals(['Bloating']));
    expect(added.containsKey('tags'), isFalse);
    expect(added[logEntriesKey], isNull);

    final again = added
        .withCustomSymptomName('Bloating')
        .withCustomSymptomName('   ');
    expect(again.customSymptomNames, equals(['Bloating']));
    expect(
      again.availableSymptomNames,
      equals([...seededSymptomNames, 'Bloating']),
    );
  });

  test('a custom name that duplicates a seeded name is ignored', () {
    final document = <String, Object?>{}.withCustomSymptomName('Cramps');

    expect(document.customSymptomNames, isEmpty);
    expect(document.availableSymptomNames, equals(seededSymptomNames));
  });

  test('a custom symptom can carry a severity or value', () {
    final document = <String, Object?>{}
        .withCustomSymptomName('Bloating')
        .withLoggedSymptom(day, 'Bloating', value: 'Severe');

    expect(document.symptomsFor(day).single.name, 'Bloating');
    expect(document.symptomsFor(day).single.value, 'Severe');
    expect(document.containsKey('tags'), isFalse);
  });

  test('rewriting a value preserves symptom fields from later slices', () {
    final document = <String, Object?>{
      logEntriesKey: <Object?>[
        <String, Object?>{
          'date': '2026-11-18',
          'symptoms': <Object?>[
            <String, Object?>{
              'name': 'Cramps',
              'value': 'Mild',
              'futureField': 'keep',
            },
          ],
        },
      ],
    };

    final updated = document.withLoggedSymptom(day, 'Cramps', value: 'Severe');

    expect(updated.symptomsFor(day).single.value, 'Severe');
    final stored = (updated[logEntriesKey] as List).single as Map<String, Object?>;
    final storedSymptom = (stored[symptomsKey] as List).single
        as Map<String, Object?>;
    expect(storedSymptom['futureField'], 'keep');
  });

  test('only days with a logged symptom appear in the symptom review', () {
    final document = <String, Object?>{}
        .withLoggedSymptom(day, 'Sleep')
        .withPeriodDay(day.add(const Duration(days: 1)));

    expect(document.symptomDays, hasLength(1));
    expect(document.symptomDays.single.dayKey, '2026-11-18');
  });
}
