import 'package:flutter_test/flutter_test.dart';

import 'package:moonpetal/src/cycles.dart';
import 'package:moonpetal/src/log_entries.dart';

void main() {
  final day = DateTime(2026, 11, 18);
  final originalAt = DateTime(2026, 11, 18, 8, 30);
  final correctedAt = DateTime(2026, 11, 18, 9, 15);

  test('a corrected note keeps the original value and its timestamp', () {
    final written = <String, Object?>{}.withNote(
      day,
      'Felt great',
      at: originalAt,
    );
    final corrected = written.withNote(day, 'Actually tired', at: correctedAt);

    final history = corrected.editHistoryFor(day, noteKey);
    expect(
      history.map((record) => record.value),
      equals(['Felt great', 'Actually tired']),
    );
    expect(history.first.at, originalAt);
    expect(history.last.at, correctedAt);
    expect(corrected.noteFor(day), 'Actually tired');
  });

  test('a corrected flow level keeps the original level and its timestamp', () {
    final logged = <String, Object?>{}.withFlowLevel(
      day,
      FlowLevel.light,
      at: originalAt,
    );
    final corrected = logged.withFlowLevel(
      day,
      FlowLevel.heavy,
      at: correctedAt,
    );

    final history = corrected.editHistoryFor(day, flowLevelKey);
    expect(
      history.map((record) => record.value),
      equals(['light', 'heavy']),
    );
    expect(history.first.at, originalAt);
    expect(corrected.flowLevelFor(day), FlowLevel.heavy);
  });

  test('clearing a flow level records the deletion with its timestamp', () {
    final logged = <String, Object?>{}.withFlowLevel(
      day,
      FlowLevel.medium,
      at: originalAt,
    );
    final cleared = logged.withFlowLevel(day, null, at: correctedAt);

    final history = cleared.editHistoryFor(day, flowLevelKey);
    expect(
      history.map((record) => record.value),
      equals(['medium', null]),
    );
    expect(history.first.at, originalAt);
    expect(history.last.at, correctedAt);
    expect(cleared.flowLevelFor(day), isNull);
  });

  test('removing a period day keeps the original mark and its timestamp', () {
    final logged = <String, Object?>{}.withPeriodDay(day, at: originalAt);
    final removed = logged.withoutPeriodDay(day, at: correctedAt);

    final history = removed.editHistoryFor(day, periodDayKey);
    expect(history.map((record) => record.value), equals([true, null]));
    expect(history.first.at, originalAt);
    expect(removed.periodDays.containsDay(day), isFalse);
    expect(removed.editHistoryFor(day, periodDayKey), hasLength(2));
  });

  test('changing a symptom keeps the original value and its timestamp', () {
    final logged = <String, Object?>{}.withLoggedSymptom(
      day,
      'Cramps',
      value: 'Mild',
      at: originalAt,
    );
    final corrected = logged.withLoggedSymptom(
      day,
      'Cramps',
      value: 'Severe',
      at: correctedAt,
    );

    final history = corrected.editHistoryFor(
      day,
      symptomHistoryField('Cramps'),
    );
    expect(history.map((record) => record.value), equals(['Mild', 'Severe']));
    expect(history.first.at, originalAt);
    expect(corrected.symptomsFor(day).single.value, 'Severe');
  });

  test('attaching then removing a tag keeps both changes with timestamps', () {
    final attached = <String, Object?>{}.withTag(
      day,
      'doctor',
      at: originalAt,
    );
    final removed = attached.withoutTag(day, 'doctor', at: correctedAt);

    final history = removed.editHistoryFor(day, tagHistoryField('doctor'));
    expect(history.map((record) => record.value), equals(['doctor', null]));
    expect(history.first.at, originalAt);
    expect(history.last.at, correctedAt);
    expect(removed.tagsFor(day), isEmpty);
  });

  test('removing a period day recomputes the derived cycle history', () {
    final document = <String, Object?>{}
        .withPeriodDay(DateTime(2026, 1, 1), at: originalAt)
        .withPeriodDay(DateTime(2026, 1, 2), at: originalAt)
        .withPeriodDay(DateTime(2026, 1, 29), at: originalAt);

    expect(document.cycleHistory, hasLength(1));

    final corrected = document.withoutPeriodDay(
      DateTime(2026, 1, 29),
      at: correctedAt,
    );

    expect(corrected.cycleHistory, isEmpty);
  });

  test('logging the same period day twice does not duplicate its history', () {
    final logged = <String, Object?>{}.withPeriodDay(day, at: originalAt);
    final tappedAgain = logged.withPeriodDay(day, at: correctedAt);

    expect(tappedAgain.editHistoryFor(day, periodDayKey), hasLength(1));
    expect(tappedAgain.editHistoryFor(day, periodDayKey).single.at, originalAt);
  });

  test('deleting a log entry clears its values but keeps the edit history', () {
    final populated = <String, Object?>{}
        .withPeriodDay(day, at: originalAt)
        .withFlowLevel(day, FlowLevel.light, at: originalAt)
        .withNote(day, 'A note', at: originalAt);
    final deleted = populated.deleteLogEntry(day, at: correctedAt);

    expect(deleted.logEntries.forDay(day), isNotNull);
    expect(deleted.periodDays.containsDay(day), isFalse);
    expect(deleted.flowLevelFor(day), isNull);
    expect(deleted.noteFor(day), isNull);
    expect(
      deleted.editHistoryForDay(day).map((value) => value.value),
      equals([true, 'light', 'A note', null, null, null]),
    );
    expect(deleted.editHistoryForDay(day).last.at, correctedAt);
  });
}
