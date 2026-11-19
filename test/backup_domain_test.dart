import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:moonpetal/src/backup.dart';
import 'package:moonpetal/src/fertility.dart';
import 'package:moonpetal/src/log_entries.dart';
import 'package:moonpetal/src/periods.dart';
import 'package:moonpetal/src/reminders.dart';
import 'package:moonpetal/src/storage.dart';

import 'helpers/backup.dart';

Matcher invalidBackup(String text) => throwsA(
  isA<InvalidBackupException>().having((error) => error.message, 'message', contains(text)),
);

void main() {
  test('a backup is one indented JSON file naming the app and its data', () {
    final contents = encodeBackup(richBackupDocument());
    final decoded = jsonDecode(contents) as Map<String, dynamic>;

    // Human-readable: indentation and newlines, not one opaque blob.
    expect(contents, contains('\n  '));
    expect(decoded[backupFormatKey], backupFormatName);
    expect(decoded[backupVersionKey], backupVersion);
    expect(decoded[backupDataKey], isA<Map<String, dynamic>>());
  });

  test('a backup contains log entries, edit history and every setting', () {
    final contents = encodeBackup(richBackupDocument());

    expect(contents, contains(logEntriesKey));
    expect(contents, contains(editHistoryKey));
    expect(contents, contains(flowLevelKey));
    expect(contents, contains(symptomsKey));
    expect(contents, contains(noteKey));
    expect(contents, contains(tagsKey));
    expect(contents, contains(symptomNamesKey));
    expect(contents, contains(tagNamesKey));
    expect(contents, contains(fertilityViewEnabledKey));
    expect(contents, contains(remindersKey));
    expect(contents, contains(periodEndsKey));
  });

  test('a valid backup round-trips every entry, history and setting', () {
    final original = richBackupDocument();

    final restored = decodeBackup(encodeBackup(original));

    expect(restored, equals(original));
    expect(
      restored.editHistoryFor(DateTime(2026, 1, 1), noteKey).map((v) => v.value),
      equals(['First day', 'Corrected note']),
    );
    expect(restored.fertilityViewEnabled, isTrue);
    expect(restored.reminderSettings.dailyLoggingTime.hour, 21);
    expect(restored.reminderSettings.dailyLoggingTime.minute, 30);
  });

  test('a settings-only backup round-trips too', () {
    final original = <String, Object?>{
      symptomNamesKey: <Object?>['Dizziness'],
      tagNamesKey: <Object?>['busy'],
      fertilityViewEnabledKey: true,
    };

    expect(decodeBackup(encodeBackup(original)), equals(original));
  });

  test('malformed JSON is reported as an invalid backup', () {
    expect(
      () => decodeBackup('{ this is not JSON'),
      invalidBackup('valid JSON'),
    );
  });

  test('a JSON file that is not a Moonpetal backup is rejected', () {
    expect(
      () => decodeBackup('{"hello":"world"}'),
      invalidBackup('not a Moonpetal backup'),
    );
  });

  test('a backup from another version is rejected', () {
    final changed = jsonDecode(encodeBackup(richBackupDocument()))
        as Map<String, dynamic>
      ..[backupVersionKey] = 99;

    expect(
      () => decodeBackup(jsonEncode(changed)),
      invalidBackup('another version'),
    );
  });

  test('a backup with a damaged log entries list is rejected', () {
    final changed = jsonDecode(encodeBackup(richBackupDocument()))
        as Map<String, dynamic>
      ..[backupDataKey] = <String, Object?>{logEntriesKey: 'not a list'};

    expect(
      () => decodeBackup(jsonEncode(changed)),
      invalidBackup('log entries'),
    );
  });

  test('a backup with an unreadable entry date is rejected', () {
    final changed = jsonDecode(encodeBackup(richBackupDocument()))
        as Map<String, dynamic>;
    final data = changed[backupDataKey] as Map<String, dynamic>;
    (data[logEntriesKey] as List).first['date'] = 'yesterday';

    expect(
      () => decodeBackup(jsonEncode(changed)),
      invalidBackup('unreadable date'),
    );
  });

  test('a backup with damaged settings is rejected', () {
    final changed = jsonDecode(encodeBackup(richBackupDocument()))
        as Map<String, dynamic>;
    final data = changed[backupDataKey] as Map<String, dynamic>;
    data[remindersKey] = 'not settings';

    expect(
      () => decodeBackup(jsonEncode(changed)),
      invalidBackup('reminder settings'),
    );
  });

  test('a backup with a non-text note is rejected before it can break reads',
      () {
    final changed = jsonDecode(encodeBackup(richBackupDocument()))
        as Map<String, dynamic>;
    final data = changed[backupDataKey] as Map<String, dynamic>;
    (data[logEntriesKey] as List).first[noteKey] = 42;

    expect(
      () => decodeBackup(jsonEncode(changed)),
      invalidBackup('note'),
    );
  });

  test('a backup with an unknown flow level is rejected', () {
    final changed = jsonDecode(encodeBackup(richBackupDocument()))
        as Map<String, dynamic>;
    final data = changed[backupDataKey] as Map<String, dynamic>;
    (data[logEntriesKey] as List).first[flowLevelKey] = ' torrential';

    expect(
      () => decodeBackup(jsonEncode(changed)),
      invalidBackup('flow level'),
    );
  });

  test('a backup with an out-of-range reminder time is rejected', () {
    final changed = jsonDecode(encodeBackup(richBackupDocument()))
        as Map<String, dynamic>;
    final data = changed[backupDataKey] as Map<String, dynamic>;
    (data[remindersKey] as Map<String, dynamic>)['dailyLoggingHour'] = 99;

    expect(
      () => decodeBackup(jsonEncode(changed)),
      invalidBackup('reminder settings'),
    );
  });
}
