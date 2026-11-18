import 'package:intl/intl.dart';

import 'storage.dart';

const String _dateKey = 'date';
const String _periodDayKey = 'periodDay';
const String _flowLevelKey = 'flowLevel';
const String symptomsKey = 'symptoms';
const String _symptomNameKey = 'name';
const String _symptomValueKey = 'value';
const String noteKey = 'note';
const String tagsKey = 'tags';

/// The small set of common symptoms offered on the daily screen from the
/// start. User-defined names are stored alongside these in the document.
const List<String> seededSymptomNames = <String>[
  'Cramps',
  'Mood',
  'Energy',
  'Headaches',
  'Sleep',
];

/// A symptom logged on a day, with an optional severity or value.
class LoggedSymptom {
  const LoggedSymptom({required this.name, this.value});

  final String name;
  final String? value;

  factory LoggedSymptom.fromJson(Map<String, Object?> json) => LoggedSymptom(
    name: json[_symptomNameKey] as String,
    value: json[_symptomValueKey] as String?,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    _symptomNameKey: name,
    if (value != null) _symptomValueKey: value,
  };
}

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
    this.symptoms = const <LoggedSymptom>[],
    this.note,
    this.tags = const <String>[],
  });

  final DateTime date;
  final bool isPeriodDay;
  final FlowLevel? flowLevel;

  /// Symptoms logged on this day, each with an optional severity or value.
  final List<LoggedSymptom> symptoms;

  /// The free-text note written on this day, if there is one.
  final String? note;

  /// Free-form labels attached to this day for the user's own organisation.
  /// These are never symptom values.
  final List<String> tags;

  String get dayKey => _dayFormat.format(date);

  factory LogEntry.fromJson(Map<String, Object?> json) => LogEntry(
    date: DateTime.parse(json[_dateKey] as String),
    isPeriodDay: json[_periodDayKey] == true,
    flowLevel: FlowLevel.values.asNameMap()[json[_flowLevelKey]],
    symptoms:
        (json[symptomsKey] as List?)
            ?.whereType<Map<String, Object?>>()
            .map(LoggedSymptom.fromJson)
            .toList() ??
        const <LoggedSymptom>[],
    note: json[noteKey] as String?,
    tags: (json[tagsKey] as List?)?.whereType<String>().toList() ??
        const <String>[],
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

  /// Index of [day]'s entry in a stored [entries] list, or -1.
  int _dayEntryIndex(List<Object?> entries, DateTime day) {
    final key = _dayFormat.format(day);
    return entries.indexWhere(
      (entry) => entry is Map<String, Object?> && entry[_dateKey] == key,
    );
  }

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

    final index = _dayEntryIndex(entries, day);
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

  /// Symptom names the user has defined themselves.
  List<String> get customSymptomNames {
    final stored = this[symptomNamesKey];
    if (stored is! List) return const <String>[];
    return stored.whereType<String>().toList();
  }

  /// Seeded symptoms first, then any custom names the user has created.
  List<String> get availableSymptomNames => <String>[
    ...seededSymptomNames,
    ...customSymptomNames,
  ];

  /// Returns a new document with [name] added to the user's custom symptoms.
  ///
  /// Names are trimmed; blank names and duplicates are ignored so reusing a
  /// custom symptom never adds another definition.
  Map<String, Object?> withCustomSymptomName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty ||
        seededSymptomNames.contains(trimmed) ||
        customSymptomNames.contains(trimmed)) {
      return this;
    }
    return <String, Object?>{
      ...this,
      symptomNamesKey: <String>[...customSymptomNames, trimmed],
    };
  }

  /// Symptoms logged on [day], in the order they were added.
  List<LoggedSymptom> symptomsFor(DateTime day) =>
      logEntries.forDay(day)?.symptoms ?? const <LoggedSymptom>[];

  /// Returns a new document with [name] toggled on [day]: logged with no
  /// value when absent, removed when already logged.
  Map<String, Object?> withToggledSymptom(DateTime day, String name) =>
      symptomsFor(day).any((symptom) => symptom.name == name)
          ? withoutLoggedSymptom(day, name)
          : withLoggedSymptom(day, name);

  /// Every day with at least one logged symptom, oldest first.
  List<LogEntry> get symptomDays =>
      logEntries.where((entry) => entry.symptoms.isNotEmpty).toList();

  /// The raw stored symptom maps for [day], copied so they can be rewritten
  /// without dropping fields this slice doesn't yet understand.
  List<Object?> _rawSymptomsFor(DateTime day) {
    final stored = this[logEntriesKey];
    if (stored is! List) return <Object?>[];
    final entries = <Object?>[...stored];
    final index = _dayEntryIndex(entries, day);
    if (index == -1) return <Object?>[];
    final symptoms = (entries[index] as Map<String, Object?>)[symptomsKey];
    if (symptoms is List) return [...symptoms];
    return <Object?>[];
  }

  /// Whether a stored symptom is the one named [name].
  bool _isSymptomNamed(Object? symptom, String name) =>
      symptom is Map<String, Object?> && symptom[_symptomNameKey] == name;

  /// Returns a new document with [name] logged on [day] at the optional
  /// [value]. Logging the same name again updates its value rather than
  /// duplicating it; all other fields and entries are preserved.
  Map<String, Object?> withLoggedSymptom(
    DateTime day,
    String name, {
    String? value,
  }) {
    final symptoms = _rawSymptomsFor(day);
    final updated = LoggedSymptom(name: name, value: value).toJson();
    final index = symptoms.indexWhere(
      (symptom) => _isSymptomNamed(symptom, name),
    );
    if (index == -1) {
      symptoms.add(updated);
    } else {
      final existing = symptoms[index] as Map<String, Object?>;
      final merged = <String, Object?>{...existing, ...updated};
      if (value == null) merged.remove(_symptomValueKey);
      symptoms[index] = merged;
    }
    return _withDayEntry(day, fields: <String, Object?>{symptomsKey: symptoms});
  }

  /// Returns a new document with [name] no longer logged on [day].
  Map<String, Object?> withoutLoggedSymptom(DateTime day, String name) {
    final symptoms = _rawSymptomsFor(day)
      ..removeWhere((symptom) => _isSymptomNamed(symptom, name));
    return _withDayEntry(day, fields: <String, Object?>{symptomsKey: symptoms});
  }

  /// The free-text note saved on [day], if there is one.
  String? noteFor(DateTime day) => logEntries.forDay(day)?.note;

  /// Every day with a saved note, oldest first.
  List<LogEntry> get noteDays =>
      logEntries.where((entry) => entry.note != null).toList();

  /// Returns a new document with [note] saved on [day].
  ///
  /// Blank notes clear the field instead of storing whitespace. Passing null
  /// clears it too; clearing a day with no entry records nothing.
  Map<String, Object?> withNote(DateTime day, String? note) {
    final trimmed = note?.trim();
    return _withDayEntry(
      day,
      fields: {if (trimmed != null && trimmed.isNotEmpty) noteKey: trimmed},
      clearKeys: <String>[noteKey],
    );
  }

  /// The free-form labels attached to [day], in the order they were added.
  List<String> tagsFor(DateTime day) =>
      logEntries.forDay(day)?.tags ?? const <String>[];

  /// Every day with at least one attached tag, oldest first.
  List<LogEntry> get tagDays =>
      logEntries.where((entry) => entry.tags.isNotEmpty).toList();

  /// Tag labels the user has created themselves, reusable on any day.
  List<String> get tagNames {
    final stored = this[tagNamesKey];
    if (stored is! List) return const <String>[];
    return stored.whereType<String>().toList();
  }

  /// Returns a new document with [name] added to the user's tags.
  ///
  /// Names are trimmed; blank names and duplicates are ignored so reusing a
  /// tag never adds another definition.
  Map<String, Object?> withTagName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || tagNames.contains(trimmed)) return this;
    return <String, Object?>{
      ...this,
      tagNamesKey: <String>[...tagNames, trimmed],
    };
  }

  /// The raw stored tags for [day], copied so they can be rewritten without
  /// dropping other fields on the entry.
  List<String> _rawTagsFor(DateTime day) {
    final stored = this[logEntriesKey];
    if (stored is! List) return <String>[];
    final entries = <Object?>[...stored];
    final index = _dayEntryIndex(entries, day);
    if (index == -1) return <String>[];
    final tags = (entries[index] as Map<String, Object?>)[tagsKey];
    if (tags is List) return tags.whereType<String>().toList();
    return <String>[];
  }

  /// Returns a new document with [name] attached to [day].
  Map<String, Object?> withTag(DateTime day, String name) {
    final tags = _rawTagsFor(day);
    if (tags.contains(name)) return this;
    return _withDayEntry(
      day,
      fields: <String, Object?>{tagsKey: <String>[...tags, name]},
    );
  }

  /// Returns a new document with [name] no longer attached to [day].
  Map<String, Object?> withoutTag(DateTime day, String name) {
    final tags = _rawTagsFor(day)..remove(name);
    return _withDayEntry(
      day,
      fields: <String, Object?>{tagsKey: tags},
    );
  }

  /// Returns a new document with [name] attached to [day], or removed when it
  /// is already attached.
  Map<String, Object?> withToggledTag(DateTime day, String name) =>
      tagsFor(day).contains(name)
          ? withoutTag(day, name)
          : withTag(day, name);
}
