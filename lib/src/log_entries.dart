import 'package:intl/intl.dart';

import 'storage.dart';

const String _dateKey = 'date';
const String _periodDayKey = 'periodDay';
const String _flowLevelKey = 'flowLevel';

final DateFormat _dayFormat = DateFormat('yyyy-MM-dd');
final DateFormat _longDateFormat = DateFormat('EEEE d MMMM y');

/// Formats a calendar day the way it is shown in the history list.
String formatLongDate(DateTime day) => _longDateFormat.format(day);

/// The four named levels of bleed intensity, lightest to heaviest.
enum FlowLevel {
  spotting('Spotting'),
  light('Light'),
  medium('Medium'),
  heavy('Heavy');

  const FlowLevel(this.label);

  /// Readable label used on chips and in reviews.
  final String label;
}

/// A single dated record of what the user observed or did.
///
/// This slice records whether the day is a period day and its Flow level.
/// Later slices add symptoms, tags and notes to the same per-day log entry.
class LogEntry {
  const LogEntry({
    required this.date,
    required this.isPeriodDay,
    this.flowLevel,
  });

  final DateTime date;
  final bool isPeriodDay;
  final FlowLevel? flowLevel;

  String get dayKey => _dayFormat.format(date);

  factory LogEntry.fromJson(Map<String, Object?> json) => LogEntry(
    date: DateTime.parse(json[_dateKey] as String),
    isPeriodDay: json[_periodDayKey] == true,
    flowLevel: FlowLevel.values.asNameMap()[json[_flowLevelKey]],
  );
}

/// Lookups over a set of log entries, kept next to the day-key format they use.
extension LogEntryList on Iterable<LogEntry> {
  /// Whether any entry records [day] as a period day.
  bool containsDay(DateTime day) =>
      any((entry) => entry.dayKey == _dayFormat.format(day));

  /// The entry recorded for [day], if there is one.
  LogEntry? forDay(DateTime day) {
    final key = _dayFormat.format(day);
    for (final entry in this) {
      if (entry.dayKey == key) return entry;
    }
    return null;
  }
}

/// Typed reads and writes for log entries on the stored document.
extension LogEntryDocument on Map<String, Object?> {
  /// Every logged day, oldest first, including days that are not period days.
  List<LogEntry> get logEntries {
    final stored = this[logEntriesKey];
    if (stored is! List) return <LogEntry>[];

    return stored
        .whereType<Map<String, Object?>>()
        .map(LogEntry.fromJson)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Logged period days, oldest first.
  List<LogEntry> get periodDays =>
      logEntries.where((entry) => entry.isPeriodDay).toList();

  /// The Flow level recorded for [day], if one has been logged.
  FlowLevel? flowLevelFor(DateTime day) => logEntries.forDay(day)?.flowLevel;

  /// Every day with a saved Flow level, oldest first, period day or not.
  List<LogEntry> get flowDays =>
      logEntries.where((entry) => entry.flowLevel != null).toList();

  /// Returns a new document with [fields] set on [day]'s entry and
  /// [clearKeys] removed from it.
  ///
  /// An entry is created only when there are fields to write, so clearing a
  /// field on an unlogged day records nothing. Unrelated entries and fields —
  /// including ones this slice doesn't yet understand — are preserved.
  Map<String, Object?> _withDayEntry(
    DateTime day, {
    Map<String, Object?> fields = const {},
    Iterable<String> clearKeys = const [],
  }) {
    final key = _dayFormat.format(day);
    final stored = this[logEntriesKey];
    final entries = <Object?>[if (stored is List) ...stored];

    final index = entries.indexWhere(
      (entry) => entry is Map<String, Object?> && entry[_dateKey] == key,
    );
    if (index == -1) {
      if (fields.isNotEmpty) {
        entries.add(<String, Object?>{_dateKey: key, ...fields});
      }
    } else {
      final existing = entries[index] as Map<String, Object?>;
      final updated = <String, Object?>{...existing}
        ..removeWhere((field, _) => clearKeys.contains(field))
        ..addAll(fields);
      entries[index] = updated;
    }

    return <String, Object?>{...this, logEntriesKey: entries};
  }

  /// Returns a new document with [day] recorded as a period day.
  ///
  /// Recording a day that is already logged leaves the entry untouched, so a
  /// second tap cannot create a duplicate.
  Map<String, Object?> withPeriodDay(DateTime day) =>
      _withDayEntry(day, fields: <String, Object?>{_periodDayKey: true});

  /// Returns a new document with [level] recorded as [day]'s flow level.
  ///
  /// Passing null clears the flow level. Every other field on the entry and
  /// all unrelated entries are preserved, so later slices can add their own
  /// data to the same log entry.
  Map<String, Object?> withFlowLevel(DateTime day, FlowLevel? level) =>
      _withDayEntry(
        day,
        fields: {if (level != null) _flowLevelKey: level.name},
        clearKeys: <String>[_flowLevelKey],
      );
}
