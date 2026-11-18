import 'package:intl/intl.dart';

import 'storage.dart';

const String _dateKey = 'date';
const String periodDayKey = 'periodDay';
const String flowLevelKey = 'flowLevel';
const String symptomsKey = 'symptoms';
const String _symptomNameKey = 'name';
const String _symptomValueKey = 'value';

/// Edit-history field prefixes for one named symptom or tag.
const String symptomHistoryPrefix = 'symptom:';
const String tagHistoryPrefix = 'tag:';

String symptomHistoryField(String name) => '$symptomHistoryPrefix$name';
String tagHistoryField(String name) => '$tagHistoryPrefix$name';

const String noteKey = 'note';
const String tagsKey = 'tags';
const String editHistoryKey = 'editHistory';

const String _historyFieldKey = 'field';
const String _historyValueKey = 'value';
const String _historyAtKey = 'at';

/// One value a field has held on a log entry, with the moment it was saved.
///
/// Values are appended oldest first, so the last one for a field is its
/// current value. A null [value] means the field was cleared.
class HistoryValue {
  const HistoryValue({
    required this.field,
    required this.value,
    required this.at,
  });

  /// The key of the field that changed, e.g. `note` or `flowLevel`.
  final String field;

  /// The value saved at [at], or null when the field was cleared.
  final Object? value;

  final DateTime at;

  factory HistoryValue.fromJson(Map<String, Object?> json) => HistoryValue(
    field: json[_historyFieldKey] as String,
    value: json[_historyValueKey],
    at: DateTime.parse(json[_historyAtKey] as String),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    _historyFieldKey: field,
    if (value != null) _historyValueKey: value,
    _historyAtKey: at.toIso8601String(),
  };
}

/// A history value only when the caller supplied a clock time.
HistoryValue? _stamped(String field, Object? value, DateTime? at) =>
    at == null ? null : HistoryValue(field: field, value: value, at: at);

/// The most recent saved value for [field] on one stored log entry.
HistoryValue? _lastHistoryValue(Map<String, Object?> entry, String field) {
  final stored = entry[editHistoryKey];
  if (stored is! List) return null;
  HistoryValue? last;
  for (final item in stored) {
    if (item is Map<String, Object?>) {
      final value = HistoryValue.fromJson(item);
      if (value.field == field) last = value;
    }
  }
  return last;
}

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
    isPeriodDay: json[periodDayKey] == true,
    flowLevel: FlowLevel.values.asNameMap()[json[flowLevelKey]],
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
    HistoryValue? history,
  }) {
    final key = _dayFormat.format(day);
    final stored = this[logEntriesKey];
    final entries = <Object?>[if (stored is List) ...stored];

    final index = _dayEntryIndex(entries, day);
    if (index == -1) {
      if (fields.isNotEmpty) {
        final entry = <String, Object?>{_dateKey: key, ...fields};
        if (history != null) {
          entry[editHistoryKey] = <Object?>[history.toJson()];
        }
        entries.add(entry);
      }
    } else {
      final existing = entries[index] as Map<String, Object?>;
      final updated = <String, Object?>{...existing}
        ..removeWhere((field, _) => clearKeys.contains(field))
        ..addAll(fields);
      if (history != null) {
        final last = _lastHistoryValue(updated, history.field);
        if (last == null || last.value != history.value) {
          final previous = updated[editHistoryKey];
          updated[editHistoryKey] = <Object?>[
            if (previous is List) ...previous,
            history.toJson(),
          ];
        }
      }
      entries[index] = updated;
    }

    return <String, Object?>{...this, logEntriesKey: entries};
  }

  /// Every edit recorded on [day], oldest first.
  List<HistoryValue> editHistoryForDay(DateTime day) {
    final stored = this[logEntriesKey];
    if (stored is! List) return const <HistoryValue>[];
    final index = _dayEntryIndex(stored, day);
    if (index == -1) return const <HistoryValue>[];
    final history = (stored[index] as Map<String, Object?>)[editHistoryKey];
    if (history is! List) return const <HistoryValue>[];
    return history
        .whereType<Map<String, Object?>>()
        .map(HistoryValue.fromJson)
        .toList();
  }

  /// The values [field] on [day] has held, oldest first.
  List<HistoryValue> editHistoryFor(DateTime day, String field) => editHistoryForDay(
    day,
  ).where((value) => value.field == field).toList();

  /// Returns a new document with every value cleared from [day]'s entry.
  ///
  /// The entry itself stays, holding its edit history, so the removal can
  /// still be reviewed. Each field that held a value gets a clearing value
  /// stamped with [at].
  Map<String, Object?> deleteLogEntry(DateTime day, {DateTime? at}) {
    final entry = logEntries.forDay(day);
    if (entry == null) return this;

    final clears = <String>[
      if (entry.isPeriodDay) periodDayKey,
      if (entry.flowLevel != null) flowLevelKey,
      if (entry.symptoms.isNotEmpty) symptomsKey,
      if (entry.note != null) noteKey,
      if (entry.tags.isNotEmpty) tagsKey,
    ];
    final stamped = <HistoryValue>[
      for (final field in clears)
        if (at != null) HistoryValue(field: field, value: null, at: at),
    ];

    final stored = this[logEntriesKey];
    final entries = <Object?>[if (stored is List) ...stored];
    final index = _dayEntryIndex(entries, day);
    final existing = entries[index] as Map<String, Object?>;
    final previous = existing[editHistoryKey];
    final updated = <String, Object?>{_dateKey: _dayFormat.format(day)};
    if (previous != null) updated[editHistoryKey] = previous;
    if (stamped.isNotEmpty) {
      updated[editHistoryKey] = <Object?>[
        if (previous is List) ...previous,
        for (final value in stamped) value.toJson(),
      ];
    }
    entries[index] = updated;
    return <String, Object?>{...this, logEntriesKey: entries};
  }

  /// Returns a new document with [day] recorded as a period day.
  ///
  /// Recording a day that is already logged leaves the entry untouched, so a
  /// second tap cannot create a duplicate.
  Map<String, Object?> withPeriodDay(DateTime day, {DateTime? at}) =>
      _withDayEntry(
        day,
        fields: <String, Object?>{periodDayKey: true},
        history: _stamped(periodDayKey, true, at),
      );

  /// Returns a new document with [day] no longer marked as a period day.
  ///
  /// The previous mark stays in the edit history with its original timestamp.
  Map<String, Object?> withoutPeriodDay(DateTime day, {DateTime? at}) =>
      _withDayEntry(
        day,
        clearKeys: <String>[periodDayKey],
        history: _stamped(periodDayKey, null, at),
      );

  /// Returns a new document with [level] recorded as [day]'s flow level.
  ///
  /// Passing null clears the flow level. Every other field on the entry and
  /// all unrelated entries are preserved, so later slices can add their own
  /// data to the same log entry.
  Map<String, Object?> withFlowLevel(
    DateTime day,
    FlowLevel? level, {
    DateTime? at,
  }) => _withDayEntry(
    day,
    fields: {if (level != null) flowLevelKey: level.name},
    clearKeys: <String>[flowLevelKey],
    history: _stamped(flowLevelKey, level?.name, at),
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
  Map<String, Object?> withToggledSymptom(
    DateTime day,
    String name, {
    DateTime? at,
  }) => symptomsFor(day).any((symptom) => symptom.name == name)
      ? withoutLoggedSymptom(day, name, at: at)
      : withLoggedSymptom(day, name, at: at);

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
    DateTime? at,
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
    return _withDayEntry(
      day,
      fields: <String, Object?>{symptomsKey: symptoms},
      history: _stamped(symptomHistoryField(name), value, at),
    );
  }

  /// Returns a new document with [name] no longer logged on [day].
  Map<String, Object?> withoutLoggedSymptom(
    DateTime day,
    String name, {
    DateTime? at,
  }) {
    final existed = symptomsFor(day).any((symptom) => symptom.name == name);
    final symptoms = _rawSymptomsFor(day)
      ..removeWhere((symptom) => _isSymptomNamed(symptom, name));
    return _withDayEntry(
      day,
      fields: <String, Object?>{symptomsKey: symptoms},
      history: existed ? _stamped(symptomHistoryField(name), null, at) : null,
    );
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
  Map<String, Object?> withNote(DateTime day, String? note, {DateTime? at}) {
    final trimmed = note?.trim();
    final value = trimmed != null && trimmed.isNotEmpty ? trimmed : null;
    return _withDayEntry(
      day,
      fields: {noteKey: ?value},
      clearKeys: <String>[noteKey],
      history: _stamped(noteKey, value, at),
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
  Map<String, Object?> withTag(DateTime day, String name, {DateTime? at}) {
    final tags = _rawTagsFor(day);
    if (tags.contains(name)) return this;
    return _withDayEntry(
      day,
      fields: <String, Object?>{tagsKey: <String>[...tags, name]},
      history: _stamped(tagHistoryField(name), name, at),
    );
  }

  /// Returns a new document with [name] no longer attached to [day].
  Map<String, Object?> withoutTag(DateTime day, String name, {DateTime? at}) {
    if (!tagsFor(day).contains(name)) return this;
    final tags = _rawTagsFor(day)..remove(name);
    return _withDayEntry(
      day,
      fields: <String, Object?>{tagsKey: tags},
      history: _stamped(tagHistoryField(name), null, at),
    );
  }

  /// Returns a new document with [name] attached to [day], or removed when it
  /// is already attached.
  Map<String, Object?> withToggledTag(
    DateTime day,
    String name, {
    DateTime? at,
  }) => tagsFor(day).contains(name)
      ? withoutTag(day, name, at: at)
      : withTag(day, name, at: at);
}
