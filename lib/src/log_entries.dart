import 'package:intl/intl.dart';

import 'storage.dart';

const String _dateKey = 'date';
const String _periodDayKey = 'periodDay';

final DateFormat _dayFormat = DateFormat('yyyy-MM-dd');
final DateFormat _longDateFormat = DateFormat('EEEE d MMMM y');

/// Formats a calendar day the way it is shown in the history list.
String formatLongDate(DateTime day) => _longDateFormat.format(day);

/// A single dated record of what the user observed or did.
///
/// This slice records only whether the day is a period day. Later slices add
/// Flow level, symptoms, tags and notes to the same per-day log entry.
class LogEntry {
  const LogEntry({required this.date, required this.isPeriodDay});

  final DateTime date;
  final bool isPeriodDay;

  String get dayKey => _dayFormat.format(date);

  factory LogEntry.fromJson(Map<String, Object?> json) => LogEntry(
        date: DateTime.parse(json[_dateKey] as String),
        isPeriodDay: json[_periodDayKey] == true,
      );
}

/// Lookups over a set of log entries, kept next to the day-key format they use.
extension LogEntryList on Iterable<LogEntry> {
  /// Whether any entry records [day] as a period day.
  bool containsDay(DateTime day) =>
      any((entry) => entry.dayKey == _dayFormat.format(day));
}

/// Typed reads and writes for log entries on the stored document.
extension LogEntryDocument on Map<String, Object?> {
  /// Logged period days, oldest first.
  List<LogEntry> get periodDays {
    final stored = this[logEntriesKey];
    if (stored is! List) return <LogEntry>[];

    return stored
        .whereType<Map<String, Object?>>()
        .map(LogEntry.fromJson)
        .where((entry) => entry.isPeriodDay)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Returns a new document with [day] recorded as a period day.
  ///
  /// Recording a day that is already logged leaves the entry untouched, so a
  /// second tap cannot create a duplicate.
  Map<String, Object?> withPeriodDay(DateTime day) {
    final key = _dayFormat.format(day);
    final stored = this[logEntriesKey];
    // Preserve every existing entry, including ones this slice doesn't yet
    // understand, so recording a day never discards stored data.
    final entries = <Object?>[if (stored is List) ...stored];

    final index = entries.indexWhere(
      (entry) => entry is Map<String, Object?> && entry[_dateKey] == key,
    );
    if (index == -1) {
      entries.add(<String, Object?>{_dateKey: key, _periodDayKey: true});
    } else {
      final existing = entries[index] as Map<String, Object?>;
      entries[index] = <String, Object?>{...existing, _periodDayKey: true};
    }

    return <String, Object?>{...this, logEntriesKey: entries};
  }
}
