import 'package:flutter_test/flutter_test.dart';

import 'package:moonpetal/src/log_entries.dart';
import 'package:moonpetal/src/storage.dart';

void main() {
  test('recording a period day leaves unrelated log entries intact', () {
    final document = <String, Object?>{
      logEntriesKey: <Object?>['an entry from a later slice'],
    };

    final updated = document.withPeriodDay(DateTime(2026, 11, 18));

    expect(updated[logEntriesKey], contains('an entry from a later slice'));
    expect(updated.periodDays, hasLength(1));
  });

  test('recording the same period day twice does not duplicate it', () {
    final day = DateTime(2026, 11, 18);
    final document = <String, Object?>{}.withPeriodDay(day);

    final updated = document.withPeriodDay(day);

    expect(updated.periodDays, hasLength(1));
    expect(updated.periodDays.containsDay(day), isTrue);
  });

  test('recording a flow level keeps the period day and unrelated entries', () {
    final day = DateTime(2026, 11, 18);
    final document = <String, Object?>{
      logEntriesKey: <Object?>['an entry from a later slice'],
    }.withPeriodDay(day);

    final updated = document.withFlowLevel(day, FlowLevel.medium);

    expect(updated[logEntriesKey], contains('an entry from a later slice'));
    final entry = updated.logEntries.forDay(day);
    expect(entry?.isPeriodDay, isTrue);
    expect(entry?.flowLevel, FlowLevel.medium);
  });

  test('clearing a flow level leaves the rest of the log entry intact', () {
    final day = DateTime(2026, 11, 18);
    final document = <String, Object?>{
      logEntriesKey: <Object?>['an entry from a later slice'],
    }.withPeriodDay(day).withFlowLevel(day, FlowLevel.heavy);

    final updated = document.withFlowLevel(day, null);

    final entry = updated.logEntries.forDay(day);
    expect(entry?.isPeriodDay, isTrue);
    expect(entry?.flowLevel, isNull);
    expect(updated[logEntriesKey], contains('an entry from a later slice'));
  });

  test('clearing a flow level on an unlogged day records nothing', () {
    final updated = <String, Object?>{}.withFlowLevel(
      DateTime(2026, 11, 18),
      null,
    );

    expect(updated.logEntries, isEmpty);
  });

  test('a flow level can be logged on a day that is not a period day', () {
    final day = DateTime(2026, 11, 18);

    final document = <String, Object?>{}.withFlowLevel(day, FlowLevel.spotting);

    final entry = document.logEntries.forDay(day);
    expect(entry?.isPeriodDay, isFalse);
    expect(entry?.flowLevel, FlowLevel.spotting);
    expect(document.hasLogEntries, isTrue);
  });
}
