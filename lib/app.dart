import 'package:flutter/material.dart';

import 'src/clock.dart';
import 'src/cycles.dart';
import 'src/estimate.dart';
import 'src/home_view.dart';
import 'src/log_entries.dart';
import 'src/periods.dart';
import 'src/phases.dart';
import 'src/phone_viewport.dart';
import 'src/storage.dart';
import 'src/theme.dart';

/// Root widget. Clock and store are injected so tests can substitute both.
class MoonpetalApp extends StatefulWidget {
  const MoonpetalApp({super.key, Clock? clock, AppStore? store})
    : clock = clock ?? const SystemClock(),
      store = store ?? const JsonFileAppStore();

  final Clock clock;
  final AppStore store;

  @override
  State<MoonpetalApp> createState() => _MoonpetalAppState();
}

class _MoonpetalAppState extends State<MoonpetalApp> {
  Map<String, Object?>? _document;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final document = await widget.store.read();
    if (!mounted) return;
    setState(() => _document = document);
  }

  /// Applies a document transform, persists it, then shows the new state.
  Future<void> _commit(
    Map<String, Object?> Function(Map<String, Object?> document) update,
  ) async {
    final updated = update(_document ?? <String, Object?>{});
    await widget.store.write(updated);
    if (!mounted) return;
    setState(() => _document = updated);
  }

  Future<void> _recordPeriodDay(DateTime day) => _commit(
    (document) => document.withPeriodDay(day, at: widget.clock.now()),
  );

  Future<void> _removePeriodDay(DateTime day) => _commit(
    (document) => document.withoutPeriodDay(day, at: widget.clock.now()),
  );

  /// Clears every value on [day], leaving the edit history reviewable.
  Future<void> _deleteEntry(DateTime day) => _commit(
    (document) => document.deleteLogEntry(day, at: widget.clock.now()),
  );

  Future<void> _logPeriodDay() => _recordPeriodDay(widget.clock.now());

  Future<void> _recordFlowLevel(DateTime day, FlowLevel? level) => _commit(
    (document) => document.withFlowLevel(day, level, at: widget.clock.now()),
  );

  Future<void> _setFlowLevel(FlowLevel? level) =>
      _recordFlowLevel(widget.clock.now(), level);

  Future<void> _endPeriod(Period period, DateTime end) =>
      _commit((document) => document.withPeriodEnd(period, end));

  /// Sets the optional severity or value on [day]'s logged [name].
  Future<void> _setSymptomValue(DateTime day, String name, String? value) =>
      _commit(
        (document) => document.withLoggedSymptom(
          day,
          name,
          value: value,
          at: widget.clock.now(),
        ),
      );

  /// Removes [name] from [day], keeping the change in the edit history.
  Future<void> _removeSymptom(DateTime day, String name) => _commit(
    (document) =>
        document.withoutLoggedSymptom(day, name, at: widget.clock.now()),
  );

  /// Saves a free-text note for [day]; null or blank clears it.
  Future<void> _saveNoteFor(DateTime day, String? note) => _commit(
    (document) => document.withNote(day, note, at: widget.clock.now()),
  );

  /// Saves a free-text note for today; null or blank clears it.
  Future<void> _saveNote(String? note) => _saveNoteFor(widget.clock.now(), note);

  /// Defines a custom symptom name for reuse on any day.
  Future<void> _addCustomSymptom(String name) =>
      _commit((document) => document.withCustomSymptomName(name));

  /// Defines a tag label for reuse on any day.
  Future<void> _addTagName(String name) =>
      _commit((document) => document.withTagName(name));

  /// Attaches a tag to [day], or removes it when it is already attached.
  Future<void> _toggleTagFor(DateTime day, String name) => _commit(
    (document) => document.withToggledTag(day, name, at: widget.clock.now()),
  );

  /// Attaches a tag to today, or removes it when it is already attached.
  Future<void> _toggleTag(String name) => _toggleTagFor(widget.clock.now(), name);

  /// Removes [name] from [day], keeping the change in the edit history.
  Future<void> _removeTag(DateTime day, String name) => _commit(
    (document) => document.withoutTag(day, name, at: widget.clock.now()),
  );

  /// Replaces one tag with another on [day], recording both changes.
  Future<void> _correctTag(DateTime day, String oldName, String newName) {
    final at = widget.clock.now();
    return _commit(
      (document) => document
          .withTagName(newName)
          .withoutTag(day, oldName, at: at)
          .withTag(day, newName, at: at),
    );
  }

  /// Taps a symptom chip on the daily screen: logs it for today, or removes
  /// it when it is already logged.
  Future<void> _toggleSymptom(String name) => _commit(
    (document) => document.withToggledSymptom(
      widget.clock.now(),
      name,
      at: widget.clock.now(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final document = _document;
    final nextPeriodEstimate = document == null
        ? null
        : estimateNextPeriod(document.cycleHistory, today: widget.clock.now());
    final phaseEstimates = nextPeriodEstimate == null || document == null
        ? <PhaseEstimate>[]
        : estimatePhases(
            cycles: document.cycleHistory,
            nextPeriod: nextPeriodEstimate,
          );

    return MaterialApp(
      title: 'Moonpetal',
      debugShowCheckedModeBanner: false,
      theme: moonpetalTheme,
      home: PhoneViewport(
        child: document == null
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : HomeView(
                today: widget.clock.now(),
                hasLogEntries: document.hasLogEntries,
                periodDays: document.periodDays,
                flowDays: document.flowDays,
                periods: document.periods,
                cycleHistory: document.cycleHistory,
                nextPeriodEstimate: nextPeriodEstimate,
                phaseEstimates: phaseEstimates,
                todayFlowLevel: document.flowLevelFor(widget.clock.now()),
                symptomNames: document.availableSymptomNames,
                todaySymptoms: document.symptomsFor(widget.clock.now()),
                symptomDays: document.symptomDays,
                todayNote: document.noteFor(widget.clock.now()),
                noteDays: document.noteDays,
                tagNames: document.tagNames,
                todayTags: document.tagsFor(widget.clock.now()),
                tagDays: document.tagDays,
                onLogPeriodDay: _logPeriodDay,
                onSetPeriodStart: _recordPeriodDay,
                onRemovePeriodDay: _removePeriodDay,
                onDeleteEntry: _deleteEntry,
                onSetFlowLevel: _setFlowLevel,
                onCorrectFlowLevel: _recordFlowLevel,
                onAddCustomSymptom: _addCustomSymptom,
                onToggleSymptom: _toggleSymptom,
                onSetSymptomValue: _setSymptomValue,
                onRemoveSymptom: _removeSymptom,
                onAddTagName: _addTagName,
                onToggleTag: _toggleTag,
                onRemoveTag: _removeTag,
                onCorrectTag: _correctTag,
                onSaveNote: _saveNote,
                onCorrectNote: _saveNoteFor,
                onEndPeriod: _endPeriod,
                editHistoryForDay: document.editHistoryForDay,
              ),
      ),
    );
  }
}
