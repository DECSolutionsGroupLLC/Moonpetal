import 'dart:convert';

import 'package:moonpetal/src/log_entries.dart';
import 'package:moonpetal/src/periods.dart';
import 'package:moonpetal/src/reminders.dart';
import 'package:moonpetal/src/storage.dart';

const String backupFormatKey = 'format';
const String backupFormatName = 'moonpetal-backup';
const String backupVersionKey = 'version';
const int backupVersion = 1;
const String backupDataKey = 'data';

const String _entryDateKey = 'date';
const String _symptomNameKey = 'name';
const String _symptomValueKey = 'value';
const String _historyFieldKey = 'field';
const String _historyAtKey = 'at';

/// A problem with the backup file itself, safe to show the user as-is.
class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => 'BackupException: $message';
}

/// The chosen file is not a Moonpetal backup this app can safely restore.
class InvalidBackupException extends BackupException {
  const InvalidBackupException(super.message);

  @override
  String toString() => 'InvalidBackupException: $message';
}

/// One human-readable JSON text file: the whole stored document, wrapped with
/// a small self-describing header so an unrelated file cannot be mistaken for
/// a backup. Nothing here touches a filesystem or the network.
String encodeBackup(Map<String, Object?> document) =>
    const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      backupFormatKey: backupFormatName,
      backupVersionKey: backupVersion,
      backupDataKey: document,
    });

/// Parses and checks a backup before any of its data is allowed near the store.
///
/// Unknown keys are preserved, so a future field cannot make an older backup
/// unreadable. Known fields must be well-formed: a damaged file is rejected
/// here rather than leaving the app with data it cannot interpret.
Map<String, Object?> decodeBackup(String contents) {
  final Object? decoded;
  try {
    decoded = jsonDecode(contents);
  } on FormatException {
    throw const InvalidBackupException('The file is not valid JSON.');
  }

  if (decoded is! Map || decoded.keys.any((key) => key is! String)) {
    throw const InvalidBackupException(
      'The file does not contain a Moonpetal backup.',
    );
  }
  final wrapper = Map<String, Object?>.from(decoded);
  if (wrapper[backupFormatKey] != backupFormatName) {
    throw const InvalidBackupException(
      'This is not a Moonpetal backup file.',
    );
  }
  if (wrapper[backupVersionKey] != backupVersion) {
    throw const InvalidBackupException(
      'This backup was made by another version of Moonpetal.',
    );
  }

  final data = wrapper[backupDataKey];
  if (data is! Map || data.keys.any((key) => key is! String)) {
    throw const InvalidBackupException('The backup is missing its data.');
  }
  final document = Map<String, Object?>.from(data);
  _validateDocument(document);
  return document;
}

void _require(bool condition, String message) {
  if (!condition) throw InvalidBackupException(message);
}

bool _isStoredDate(Object? value) {
  if (value is! String) return false;
  try {
    DateTime.parse(value);
    return true;
  } on FormatException {
    return false;
  }
}

final RegExp _dayKeyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Day keys are what the app writes and looks entries up by, so a parseable
/// date in another shape would break later corrections even if it decodes.
bool _isDayKey(Object? value) =>
    value is String &&
    _dayKeyPattern.hasMatch(value) &&
    _isStoredDate(value);

void _validateStringList(Object? value, String label) {
  if (value == null) return;
  _require(
    value is List && value.every((item) => item is String),
    'The backup has damaged $label.',
  );
}

void _validateDocument(Map<String, Object?> document) {
  final entries = document[logEntriesKey];
  if (entries != null) {
    _require(entries is List, 'The backup has a damaged log entries list.');
    for (final entry in entries as List) {
      _require(entry is Map, 'The backup contains a damaged log entry.');
      final fields = Map<String, Object?>.from(entry as Map);
      _require(
        _isDayKey(fields[_entryDateKey]),
        'The backup contains a log entry with an unreadable date.',
      );

      if (fields.containsKey(periodDayKey)) {
        _require(
          fields[periodDayKey] is bool,
          'The backup contains a damaged period day.',
        );
      }
      final flowLevel = fields[flowLevelKey];
      if (flowLevel != null) {
        _require(
          flowLevel is String && FlowLevel.values.asNameMap().containsKey(flowLevel),
          'The backup contains an unknown flow level.',
        );
      }
      if (fields.containsKey(noteKey)) {
        _require(
          fields[noteKey] == null || fields[noteKey] is String,
          'The backup contains a damaged note.',
        );
      }

      final symptoms = fields[symptomsKey];
      if (symptoms != null) {
        _require(symptoms is List, 'The backup has damaged symptoms.');
        for (final symptom in symptoms as List) {
          _require(
            symptom is Map && symptom[_symptomNameKey] is String,
            'The backup contains a damaged symptom.',
          );
          final value = (symptom as Map)[_symptomValueKey];
          _require(
            value == null || value is String,
            'The backup contains a damaged symptom value.',
          );
        }
      }
      _validateStringList(fields[tagsKey], 'tags');

      final history = fields[editHistoryKey];
      if (history != null) {
        _require(history is List, 'The backup has damaged edit history.');
        for (final record in history as List) {
          _require(
            record is Map &&
                record[_historyFieldKey] is String &&
                _isStoredDate(record[_historyAtKey]),
            'The backup contains a damaged edit history record.',
          );
        }
      }
    }
  }

  _validateStringList(document[symptomNamesKey], 'symptom names');
  _validateStringList(document[tagNamesKey], 'tag names');

  if (document.containsKey(fertilityViewEnabledKey)) {
    _require(
      document[fertilityViewEnabledKey] is bool,
      'The backup has damaged fertility settings.',
    );
  }

  final reminders = document[remindersKey];
  if (reminders != null) {
    _require(reminders is Map, 'The backup has damaged reminder settings.');
    final stored = Map<String, Object?>.from(reminders as Map);
    // Parsing through the real Settings reader avoids duplicating its keys:
    // a wrong type falls back to a default and no longer matches the file.
    final parsed = document.reminderSettings;
    final parsedJson = parsed.toJson();
    _require(
      stored.entries.every(
        (entry) => parsedJson[entry.key] == entry.value,
      ),
      'The backup has damaged reminder settings.',
    );
    _require(
      parsed.dailyLoggingTime.hour >= 0 &&
          parsed.dailyLoggingTime.hour <= 23 &&
          parsed.dailyLoggingTime.minute >= 0 &&
          parsed.dailyLoggingTime.minute <= 59,
      'The backup has damaged reminder settings.',
    );
  }

  final ends = document[periodEndsKey];
  if (ends != null) {
    _require(ends is Map, 'The backup has damaged period ends.');
    for (final end in (ends as Map).values) {
      _require(_isDayKey(end), 'The backup has an unreadable period end.');
    }
  }
}

/// A file the user picked to restore, with a name for the status message.
class PickedBackup {
  const PickedBackup({required this.name, required this.contents});

  final String name;
  final String contents;
}

/// The outward boundary for the user-chosen backup location. The app only
/// sees a display name and text; the native side owns dialogs and file I/O,
/// and never uploads or shares anything.
abstract interface class BackupGateway {
  /// Opens a save dialog, writes [contents], and returns where it was saved,
  /// or null when the user cancels.
  Future<String?> save(String suggestedName, String contents);

  /// Opens a pick dialog and reads the chosen file, or returns null when the
  /// user cancels.
  Future<PickedBackup?> load();
}
