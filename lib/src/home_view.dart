import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'about_view.dart';
import 'backup_view.dart';
import 'cycles.dart';
import 'estimate.dart';
import 'fertility.dart';
import 'insights.dart';
import 'insights_view.dart';
import 'link_launcher.dart';
import 'log_entries.dart';
import 'phases.dart';
import 'periods.dart';
import 'phone_viewport.dart';
import 'reminders.dart';
import 'reminders_view.dart';
import 'theme.dart';

/// Plain-language explanation of how Cycle length is counted.
const String cycleLengthExplanation =
    'Cycle length counts the days from one period start to the next period '
    'start.';

/// Why the cycle calendar's phases are estimates, in plain language.
const String phaseCalendarExplanation =
    'Estimated phases for the cycle leading up to your next period, based on '
    'your logged Cycle lengths and Bleed durations. Each phase is an '
    'approximate window and an estimate, not an exact date or medical advice.';

String _daysLabel(int days) => '$days ${days == 1 ? 'day' : 'days'}';

final DateFormat _dayKeyFormat = DateFormat('yyyy-MM-dd');
final DateFormat _historyTimeFormat = DateFormat('d MMM y, HH:mm');

/// The daily screen: log today in one tap and review periods and period days.
class HomeView extends StatelessWidget {
  const HomeView({
    super.key,
    required this.today,
    required this.hasLogEntries,
    required this.periodDays,
    required this.flowDays,
    required this.periods,
    required this.cycleHistory,
    required this.nextPeriodEstimate,
    required this.phaseEstimates,
    required this.fertilityViewEnabled,
    required this.fertilityEstimate,
    required this.onToggleFertilityView,
    required this.onExportBackup,
    required this.onRestoreBackup,
    required this.reminderSettings,
    required this.notificationsAvailable,
    required this.linkLauncher,
    required this.onUpdateReminderSettings,
    required this.insights,
    required this.todayFlowLevel,
    required this.symptomNames,
    required this.todaySymptoms,
    required this.symptomDays,
    required this.todayNote,
    required this.noteDays,
    required this.tagNames,
    required this.todayTags,
    required this.tagDays,
    required this.onLogPeriodDay,
    required this.onSetPeriodStart,
    required this.onSetFlowLevel,
    required this.onAddCustomSymptom,
    required this.onToggleSymptom,
    required this.onSetSymptomValue,
    required this.onAddTagName,
    required this.onToggleTag,
    required this.onSaveNote,
    required this.onEndPeriod,
    required this.onRemovePeriodDay,
    required this.onDeleteEntry,
    required this.onCorrectFlowLevel,
    required this.onRemoveSymptom,
    required this.onRemoveTag,
    required this.onCorrectTag,
    required this.onCorrectNote,
    required this.editHistoryForDay,
  });

  final DateTime today;

  /// First run means no log entries at all, including entries that are not
  /// period days, so this is deliberately separate from [periodDays].
  final bool hasLogEntries;
  final List<LogEntry> periodDays;

  /// Every day with a saved Flow level, whether or not it is a period day.
  final List<LogEntry> flowDays;
  final List<Period> periods;
  final List<CycleRecord> cycleHistory;

  /// The next-period Estimate, recomputed from the current cycle history.
  final NextPeriodEstimate? nextPeriodEstimate;

  /// The four estimated Phases of the cycle, empty until enough is logged.
  final List<PhaseEstimate> phaseEstimates;

  /// Whether the user has opted into the fertility view. Off by default.
  final bool fertilityViewEnabled;

  /// The estimated ovulation day and fertile window, when enough is logged.
  final FertilityEstimate? fertilityEstimate;

  /// Flips the fertility opt-in, persisting the user's choice.
  final VoidCallback onToggleFertilityView;

  /// Writes a backup to a user-chosen local file; returns a status line.
  final Future<String?> Function() onExportBackup;

  /// Restores from a user-chosen file; returns a status line.
  final Future<String?> Function() onRestoreBackup;

  /// The stored reminder Settings, configurable on the reminders screen.
  final ReminderSettings reminderSettings;

  /// Whether this build can deliver local notifications.
  final bool notificationsAvailable;

  /// Hands the open-source link to an external opener from the About screen.
  final LinkLauncher linkLauncher;

  /// Persists a change to reminder Settings, using the current stored value.
  final ValueChanged<ReminderSettings Function(ReminderSettings)>
  onUpdateReminderSettings;

  /// Pattern insights recomputed from the current periods and log entries.
  final PatternInsights insights;

  /// The Flow level saved for today, if the user has recorded one.
  final FlowLevel? todayFlowLevel;

  /// Seeded symptoms plus any custom names the user has created.
  final List<String> symptomNames;

  /// Symptoms logged for today, so chips can show their saved state.
  final List<LoggedSymptom> todaySymptoms;

  /// Every day with a logged symptom, oldest first.
  final List<LogEntry> symptomDays;

  /// The free-text note saved for today, if there is one.
  final String? todayNote;

  /// Every day with a saved note, oldest first.
  final List<LogEntry> noteDays;

  /// Tag labels the user has created, available to attach on any day.
  final List<String> tagNames;

  /// Tags attached to today, so chips can show their saved state.
  final List<String> todayTags;

  /// Every day with an attached tag, oldest first.
  final List<LogEntry> tagDays;

  final VoidCallback onLogPeriodDay;

  /// Records a user-chosen day as the start of a period.
  final ValueChanged<DateTime> onSetPeriodStart;

  /// Records a Flow level for today; null clears it.
  final ValueChanged<FlowLevel?> onSetFlowLevel;

  /// Defines a custom symptom name for reuse on any day.
  final ValueChanged<String> onAddCustomSymptom;

  /// Logs a symptom for today, or removes it when it is already logged.
  final ValueChanged<String> onToggleSymptom;

  /// Sets an optional severity or value on a logged symptom; null clears it.
  final void Function(DateTime day, String name, String? value)
  onSetSymptomValue;

  /// Defines a tag label for reuse on any day.
  final ValueChanged<String> onAddTagName;

  /// Attaches a tag to today, or removes it when it is already attached.
  final ValueChanged<String> onToggleTag;

  /// Saves a free-text note for today; null or blank clears it.
  final ValueChanged<String?> onSaveNote;

  /// Records the day a period ended.
  final void Function(Period period, DateTime end) onEndPeriod;

  /// Removes the period-day mark from [day], retaining it in edit history.
  final ValueChanged<DateTime> onRemovePeriodDay;

  /// Clears every value on [day], leaving its edit history reviewable.
  final ValueChanged<DateTime> onDeleteEntry;

  /// Changes or clears the flow level recorded on [day].
  final void Function(DateTime day, FlowLevel? level) onCorrectFlowLevel;

  /// Removes a logged symptom from [day], retaining it in edit history.
  final void Function(DateTime day, String name) onRemoveSymptom;

  /// Removes a tag from [day], retaining it in edit history.
  final void Function(DateTime day, String name) onRemoveTag;

  /// Replaces [oldName] with [newName] on [day], keeping both in history.
  final void Function(DateTime day, String oldName, String newName) onCorrectTag;

  /// Changes or clears the note recorded on [day].
  final void Function(DateTime day, String? note) onCorrectNote;

  /// Every edit recorded on [day], oldest first.
  final List<HistoryValue> Function(DateTime day) editHistoryForDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTodayLogged = periodDays.containsDay(today);
    final flowLevel = todayFlowLevel;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!hasLogEntries) ...[
                _FirstRunEmptyState(today: today),
                const SizedBox(height: 24),
              ],
              if (hasLogEntries) ...[
                Text(
                  'Today, ${formatLongDate(today)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const Key('viewInsightsButton'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PhoneViewport(
                        child: InsightsView(insights: insights),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.insights),
                  label: const Text('View insights'),
                ),
                const SizedBox(height: 16),
              ],
              OutlinedButton.icon(
                key: const Key('reminderSettingsButton'),
                onPressed: () => _openReminderSettings(context),
                icon: const Icon(Icons.notifications_outlined),
                label: Text(
                  notificationsAvailable
                      ? 'Reminder settings'
                      : 'Reminder settings (Android-only)',
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('backupButton'),
                onPressed: () => _openBackup(context),
                icon: const Icon(Icons.backup_outlined),
                label: const Text('Export & restore data'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('aboutButton'),
                onPressed: () => _openAbout(context),
                icon: const Icon(Icons.info_outlined),
                label: const Text('About'),
              ),
              const SizedBox(height: 16),
              if (nextPeriodEstimate != null) ...[
                _NextPeriodEstimateCard(estimate: nextPeriodEstimate!),
                const SizedBox(height: 8),
              ],
              if (phaseEstimates.isNotEmpty) ...[
                _CycleCalendarCard(phases: phaseEstimates, today: today),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                onPressed: isTodayLogged ? null : onLogPeriodDay,
                icon: Icon(isTodayLogged ? Icons.check : Icons.add),
                label: Text(
                  isTodayLogged
                      ? 'Today is logged'
                      : 'Log today as a period day',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _setStart(context),
                icon: const Icon(Icons.event),
                label: const Text('Set a specific start date'),
              ),
              const SizedBox(height: 24),
              Text('Flow level', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final level in FlowLevel.values)
                    FilterChip(
                      label: Text(level.label),
                      selected: level == flowLevel,
                      onSelected: (selected) =>
                          onSetFlowLevel(selected ? level : null),
                    ),
                ],
              ),
              if (flowLevel != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Saved flow level: ${flowLevel.label}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text('Symptoms', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Tap a symptom to log it for today. A severity or value is '
                'optional.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final name in symptomNames)
                    FilterChip(
                      label: Text(name),
                      selected: todaySymptoms.any((symptom) => symptom.name == name),
                      onSelected: (_) => onToggleSymptom(name),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _NameField(
                fieldKey: const Key('customSymptomField'),
                buttonKey: const Key('addSymptomButton'),
                label: 'New symptom name',
                buttonLabel: 'Add symptom',
                onAdd: onAddCustomSymptom,
              ),
              const SizedBox(height: 24),
              Text('Tags', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Tags are labels for your own organisation, not symptoms.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final name in tagNames)
                    FilterChip(
                      label: Text(name),
                      selected: todayTags.contains(name),
                      onSelected: (_) => onToggleTag(name),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _NameField(
                fieldKey: const Key('customTagField'),
                buttonKey: const Key('addTagButton'),
                label: 'New tag name',
                buttonLabel: 'Add tag',
                onAdd: onAddTagName,
              ),
              const SizedBox(height: 24),
              Text('Note', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _NoteField(initialNote: todayNote, onSave: onSaveNote),
              const SizedBox(height: 24),
              _FertilityCard(
                enabled: fertilityViewEnabled,
                estimate: fertilityEstimate,
                onToggle: onToggleFertilityView,
              ),
              if (hasLogEntries) ...[
                const SizedBox(height: 32),
                Text('Periods', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                ...periods.asMap().entries.map(
                  (entry) => _PeriodCard(
                    period: entry.value,
                    daysLogged: _loggedDays(entry.key).length,
                    onEnd: () => _endPeriod(context, entry.key),
                  ),
                ),
                if (cycleHistory.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Text('Cycle history', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    cycleLengthExplanation,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...cycleHistory.map((cycle) => _CycleCard(cycle: cycle)),
                ],
                const SizedBox(height: 24),
                Text('Period days', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                ...periodDays.map(
                  (entry) => _reviewTile(
                    icon: Icons.local_florist,
                    title: formatLongDate(entry.date),
                    subtitle: 'Period day',
                    actions: _reviewActions(
                      context,
                      day: entry.date,
                      field: periodDayKey,
                      onDelete: () => onRemovePeriodDay(entry.date),
                    ),
                  ),
                ),
                if (flowDays.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Flow levels', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...flowDays.map(
                    (entry) => _reviewTile(
                      icon: Icons.water_drop,
                      title: formatLongDate(entry.date),
                      subtitle: '${entry.flowLevel!.label} flow',
                      actions: _reviewActions(
                        context,
                        day: entry.date,
                        field: flowLevelKey,
                        onEdit: () => _correctFlowLevel(
                          context,
                          entry.date,
                          entry.flowLevel,
                        ),
                      ),
                    ),
                  ),
                ],
                if (symptomDays.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Logged symptoms', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...symptomDays.expand(
                    (entry) => entry.symptoms.map(
                      (symptom) => _reviewTile(
                        icon: Icons.healing,
                        title:
                            '${symptom.name}: ${symptom.value ?? 'no severity or value'}',
                        subtitle: formatLongDate(entry.date),
                        actions: _reviewActions(
                          context,
                          day: entry.date,
                          field: symptomHistoryField(symptom.name),
                          editLabel: symptom.value == null
                              ? 'Add detail'
                              : 'Edit detail',
                          onEdit: () => _setSymptomDetail(
                            context,
                            entry.date,
                            symptom.name,
                            symptom.value,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (tagDays.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Logged tags', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...tagDays.expand(
                    (entry) => entry.tags.map(
                      (tag) => _reviewTile(
                        icon: Icons.label,
                        title: tag,
                        subtitle: formatLongDate(entry.date),
                        actions: _reviewActions(
                          context,
                          day: entry.date,
                          field: tagHistoryField(tag),
                          onEdit: () => _correctTag(context, entry.date, tag),
                          onDelete: () => onRemoveTag(entry.date, tag),
                        ),
                      ),
                    ),
                  ),
                ],
                if (noteDays.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Notes', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...noteDays.map(
                    (entry) => _reviewTile(
                      icon: Icons.note,
                      title: entry.note ?? '',
                      subtitle: formatLongDate(entry.date),
                      actions: _reviewActions(
                        context,
                        day: entry.date,
                        field: noteKey,
                        onEdit: () =>
                            _correctNote(context, entry.date, entry.note),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Your entries are stored on this device.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The logged period days belonging to the period at [index].
  ///
  /// The next period's start bounds this run, so days after a gap are not
  /// counted towards an earlier open period.
  List<DateTime> _loggedDays(int index) {
    final period = periods[index];
    final nextStart = index + 1 < periods.length
        ? periods[index + 1].start
        : null;
    return periodDays
        .map((entry) => entry.date)
        .where(
          (day) =>
              !day.isBefore(period.start) &&
              (nextStart == null || day.isBefore(nextStart)) &&
              (period.end == null || !day.isAfter(period.end!)),
        )
        .toList();
  }

  void _openBackup(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PhoneViewport(
          child: BackupView(
            onExport: onExportBackup,
            onRestore: onRestoreBackup,
          ),
        ),
      ),
    );
  }

  void _openAbout(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PhoneViewport(
          child: AboutView(linkLauncher: linkLauncher),
        ),
      ),
    );
  }

  void _openReminderSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PhoneViewport(
          child: ReminderSettingsView(
            settings: reminderSettings,
            notificationsAvailable: notificationsAvailable,
            estimate: nextPeriodEstimate,
            onUpdateSettings: onUpdateReminderSettings,
          ),
        ),
      ),
    );
  }

  Future<void> _setStart(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
    );
    if (picked == null || !context.mounted) return;
    onSetPeriodStart(picked);
  }

  Future<void> _endPeriod(BuildContext context, int index) async {
    final period = periods[index];
    final lastLoggedDay = _loggedDays(index).fold<DateTime?>(
      null,
      (latest, day) => latest == null || day.isAfter(latest) ? day : latest,
    );
    final initial = lastLoggedDay ?? period.start;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: initial,
      lastDate: today.isBefore(initial) ? initial : today,
    );
    if (picked == null || !context.mounted) return;
    onEndPeriod(period, picked);
  }

  Future<void> _setSymptomDetail(
    BuildContext context,
    DateTime day,
    String name,
    String? current,
  ) async {
    final result = await showDialog<({String? value, bool delete})>(
      context: context,
      builder: (context) => _TextCorrectionDialog(
        title: '$name detail',
        label: 'Severity or value (optional)',
        initialValue: current,
        fieldKey: const Key('symptomDetailField'),
        maxLines: 1,
      ),
    );
    if (result == null || !context.mounted) return;
    if (result.delete) {
      onRemoveSymptom(day, name);
      return;
    }
    final value = result.value?.trim();
    onSetSymptomValue(day, name, value == null || value.isEmpty ? null : value);
  }

  /// A reviewed value with its correction actions on a line of their own, so
  /// long notes cannot crowd the buttons off a narrow phone screen.
  Widget _reviewTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget actions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: MoonpetalColors.deepPink),
          title: Text(title),
          subtitle: Text(subtitle),
        ),
        actions,
        const SizedBox(height: 8),
      ],
    );
  }

  /// The Edit / Delete / History actions attached to a review row.
  Widget _reviewActions(
    BuildContext context, {
    required DateTime day,
    required String field,
    String editLabel = 'Edit',
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    final suffix = '$field-${_dayKeyFormat.format(day)}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onDelete != null)
          TextButton(
            key: Key('delete-$suffix'),
            onPressed: onDelete,
            child: const Text('Delete'),
          ),
        if (onEdit != null)
          TextButton(
            key: Key('edit-$suffix'),
            onPressed: onEdit,
            child: Text(editLabel),
          ),
        TextButton(
          key: Key('history-$suffix'),
          onPressed: () => _showHistory(context, day),
          child: const Text('History'),
        ),
      ],
    );
  }

  Future<void> _correctFlowLevel(
    BuildContext context,
    DateTime day,
    FlowLevel? current,
  ) async {
    final result = await showDialog<({FlowLevel? level, bool delete})>(
      context: context,
      builder: (context) => _FlowCorrectionDialog(current: current),
    );
    if (result == null || !context.mounted) return;
    onCorrectFlowLevel(day, result.delete ? null : result.level);
  }

  Future<void> _correctTag(
    BuildContext context,
    DateTime day,
    String current,
  ) async {
    final result = await showDialog<({String? value, bool delete})>(
      context: context,
      builder: (context) => _TextCorrectionDialog(
        title: 'Correct tag',
        label: 'Tag label',
        initialValue: current,
        maxLines: 1,
      ),
    );
    if (result == null || !context.mounted) return;
    if (result.delete) {
      onRemoveTag(day, current);
      return;
    }
    final value = result.value?.trim();
    if (value == null || value.isEmpty) return;
    onCorrectTag(day, current, value);
  }

  Future<void> _correctNote(
    BuildContext context,
    DateTime day,
    String? current,
  ) async {
    final result = await showDialog<({String? value, bool delete})>(
      context: context,
      builder: (context) => _TextCorrectionDialog(
        title: 'Correct note',
        label: 'Note',
        initialValue: current,
      ),
    );
    if (result == null || !context.mounted) return;
    final value = result.value?.trim();
    onCorrectNote(day, result.delete || value == null || value.isEmpty ? null : value);
  }

  void _showHistory(BuildContext context, DateTime day) {
    showDialog<void>(
      context: context,
      builder: (context) => _HistoryDialog(
        day: day,
        records: editHistoryForDay(day),
        onDeleteEntry: () {
          Navigator.pop(context);
          onDeleteEntry(day);
        },
      ),
    );
  }
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    required this.period,
    required this.daysLogged,
    required this.onEnd,
  });

  final Period period;
  final int daysLogged;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final end = period.end;
    final duration = period.bleedDurationDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              period.isOpen ? 'Open period' : 'Period',
              style: theme.textTheme.titleMedium?.copyWith(
                color: MoonpetalColors.deepPink,
              ),
            ),
            const SizedBox(height: 4),
            Text('Started ${formatLongDate(period.start)}'),
            Text('$daysLogged ${daysLogged == 1 ? 'day' : 'days'} logged'),
            if (end != null) ...[
              const SizedBox(height: 4),
              Text('Ended ${formatLongDate(end)}'),
              Text(
                'Bleed duration: $duration ${duration == 1 ? 'day' : 'days'}',
              ),
            ] else ...[
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: onEnd,
                child: const Text('Mark as ended'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The next-period Estimate, shown as a date inside a visible range rather
/// than as a single promised day.
class _NextPeriodEstimateCard extends StatelessWidget {
  const _NextPeriodEstimateCard({required this.estimate});

  final NextPeriodEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: const Key('nextPeriodEstimate'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Next period Estimate',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: MoonpetalColors.deepPink,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: MoonpetalColors.softPink,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Estimate',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: MoonpetalColors.deepPink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Around ${formatLongDate(estimate.date)}'),
            Text(
              'Between ${formatLongDate(estimate.rangeStart)} and '
              '${formatLongDate(estimate.rangeEnd)}',
            ),
            const SizedBox(height: 4),
            Text('This window spans about ${estimate.windowDays} days.'),
            const SizedBox(height: 8),
            Text(
              estimate.explanation,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Every readable Phase detail in one place, so the Phases cannot drift apart.
extension _PhaseStyle on CyclePhase {
  String get label => switch (this) {
    CyclePhase.menstrual => 'Menstrual',
    CyclePhase.follicular => 'Follicular',
    CyclePhase.ovulatory => 'Ovulatory',
    CyclePhase.luteal => 'Luteal',
  };

  String get hint => switch (this) {
    CyclePhase.menstrual => 'bleeding days',
    CyclePhase.follicular => 'before mid-cycle',
    CyclePhase.ovulatory => 'around mid-cycle',
    CyclePhase.luteal => 'after mid-cycle',
  };

  /// Distinct soft tints, all light enough for deep-pink ink to stay readable.
  Color get tint => switch (this) {
    CyclePhase.menstrual => const Color(0xFFECA8C6),
    CyclePhase.follicular => const Color(0xFFFDE2EC),
    CyclePhase.ovulatory => const Color(0xFFF0B7D2),
    CyclePhase.luteal => const Color(0xFFE6D0E8),
  };
}

/// A small calendar of the estimated Cycle, with all four Phases labelled as
/// estimates. The day strip gives the visual; the legend gives the words.
class _CycleCalendarCard extends StatelessWidget {
  const _CycleCalendarCard({required this.phases, required this.today});

  final List<PhaseEstimate> phases;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: const Key('cycleCalendar'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Cycle calendar',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: MoonpetalColors.deepPink,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: MoonpetalColors.softPink,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Estimate',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: MoonpetalColors.deepPink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              phaseCalendarExplanation,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _PhaseDayStrip(phases: phases, today: today),
            const SizedBox(height: 12),
            ...phases.map((phase) => _PhaseLegendRow(phase: phase)),
          ],
        ),
      ),
    );
  }
}

/// A coloured day strip for the estimated Cycle, with a "you are here" cue.
/// No day is ever marked "safe".
class _PhaseDayStrip extends StatelessWidget {
  const _PhaseDayStrip({required this.phases, required this.today});

  final List<PhaseEstimate> phases;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cells = <Widget>[];
    CyclePhase? todayPhase;
    var day = phases.first.start;
    while (!day.isAfter(phases.last.end)) {
      final phase = phases.firstWhere(
        (candidate) =>
            !day.isBefore(candidate.start) && !day.isAfter(candidate.end),
      );
      final isToday =
          day.year == today.year &&
          day.month == today.month &&
          day.day == today.day;
      if (isToday) todayPhase = phase.phase;
      cells.add(
        Semantics(
          label: '${isToday ? 'Today, ' : ''}'
              '${phase.phase.label} phase (estimate), ${formatLongDate(day)}',
          child: Container(
            width: 34,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: phase.phase.tint,
              borderRadius: BorderRadius.circular(6),
              border: isToday
                  ? Border.all(color: MoonpetalColors.deepPink, width: 2)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: MoonpetalColors.deepPink,
                  ),
                ),
                Text(
                  phase.phase.label.substring(0, 1),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: MoonpetalColors.deepPink,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      day = addCalendarDays(day, 1);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 2, runSpacing: 4, children: cells),
        if (todayPhase != null) ...[
          const SizedBox(height: 8),
          Text('Today: estimated ${todayPhase.label.toLowerCase()} phase.'),
        ],
      ],
    );
  }
}

/// The readable label, estimate badge, and estimated dates for one Phase.
class _PhaseLegendRow extends StatelessWidget {
  const _PhaseLegendRow({required this.phase});

  final PhaseEstimate phase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final format = DateFormat('d MMM');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: phase.phase.tint,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      phase.phase.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: MoonpetalColors.deepPink,
                      ),
                    ),
                    Container(
                      key: Key('phase-estimate-${phase.phase.name}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: MoonpetalColors.softPink,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Estimate',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: MoonpetalColors.deepPink,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${phase.phase.hint}: '
                  '${format.format(phase.start)} – ${format.format(phase.end)}',
                  key: Key('phase-range-${phase.phase.name}'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The opt-in fertility view. Off until the user turns it on; the
/// contraception notice is a permanent part of the view and no day is ever
/// coloured "safe".
class _FertilityCard extends StatelessWidget {
  const _FertilityCard({
    required this.enabled,
    required this.estimate,
    required this.onToggle,
  });

  final bool enabled;
  final FertilityEstimate? estimate;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fertility = estimate;

    return Card(
      key: const Key('fertilityView'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fertility view',
              style: theme.textTheme.titleMedium?.copyWith(
                color: MoonpetalColors.deepPink,
              ),
            ),
            SwitchListTile(
              key: const Key('fertilityViewSwitch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Show fertility estimates'),
              subtitle: const Text(
                'Off by default. Turn on to see an Ovulation estimate and a '
                'Fertile window.',
              ),
              value: enabled,
              onChanged: (_) => onToggle(),
            ),
            if (enabled) ...[
              const SizedBox(height: 8),
              if (fertility != null) ...[
                _FertilityEstimateRow(
                  badgeKey: const Key('estimateBadge-ovulation'),
                  title: 'Ovulation estimate',
                  detailKey: const Key('ovulation-date'),
                  detail: 'Around ${formatLongDate(fertility.ovulationDay)}',
                ),
                const SizedBox(height: 12),
                _FertilityEstimateRow(
                  badgeKey: const Key('estimateBadge-fertileWindow'),
                  title: 'Fertile window',
                  detailKey: const Key('fertile-window-range'),
                  detail: 'Between ${formatLongDate(fertility.fertileStart)} '
                      'and ${formatLongDate(fertility.fertileEnd)}',
                ),
              ] else ...[
                const Text(
                  'Log at least two cycles to see fertility estimates.',
                ),
              ],
              const SizedBox(height: 12),
              Container(
                key: const Key('fertilityContraceptionNotice'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MoonpetalColors.softPink,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'These estimates are not reliable contraception. Do not use '
                  'them to avoid pregnancy.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: MoonpetalColors.deepPink,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One labelled fertility estimate: a title, an "Estimate" badge, and the
/// readable date or range.
class _FertilityEstimateRow extends StatelessWidget {
  const _FertilityEstimateRow({
    required this.badgeKey,
    required this.title,
    required this.detailKey,
    required this.detail,
  });

  final Key badgeKey;
  final String title;
  final Key detailKey;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: MoonpetalColors.deepPink,
              ),
            ),
            Container(
              key: badgeKey,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: MoonpetalColors.softPink,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Estimate',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: MoonpetalColors.deepPink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(detail, key: detailKey),
      ],
    );
  }
}

class _CycleCard extends StatelessWidget {
  const _CycleCard({required this.cycle});

  final CycleRecord cycle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bleed = cycle.bleedDurationDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cycle starting ${formatLongDate(cycle.start)}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: MoonpetalColors.deepPink,
              ),
            ),
            const SizedBox(height: 4),
            Text('Cycle length: ${_daysLabel(cycle.cycleLengthDays)}'),
            Text(
              'Bleed duration: ${bleed == null ? 'not recorded' : _daysLabel(bleed)}',
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteField extends StatefulWidget {
  const _NoteField({required this.initialNote, required this.onSave});

  final String? initialNote;
  final ValueChanged<String?> onSave;

  @override
  State<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<_NoteField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialNote ?? '',
  );

  @override
  void didUpdateWidget(covariant _NoteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialNote != oldWidget.initialNote &&
        widget.initialNote != _controller.text) {
      _controller.text = widget.initialNote ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text;
    widget.onSave(text.trim().isEmpty ? null : text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('noteField'),
          controller: _controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Free-text note',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          key: const Key('saveNoteButton'),
          onPressed: _save,
          child: const Text('Save note'),
        ),
      ],
    );
  }
}

/// A text field plus button for defining a reusable symptom or tag name.
class _NameField extends StatefulWidget {
  const _NameField({
    required this.fieldKey,
    required this.buttonKey,
    required this.label,
    required this.buttonLabel,
    required this.onAdd,
  });

  final Key fieldKey;
  final Key buttonKey;
  final String label;
  final String buttonLabel;
  final ValueChanged<String> onAdd;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final name = _controller.text;
    if (name.trim().isEmpty) return;
    widget.onAdd(name);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: widget.fieldKey,
            controller: _controller,
            decoration: InputDecoration(
              labelText: widget.label,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _add(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonal(
          key: widget.buttonKey,
          onPressed: _add,
          child: Text(widget.buttonLabel),
        ),
      ],
    );
  }
}

class _FirstRunEmptyState extends StatelessWidget {
  const _FirstRunEmptyState({required this.today});

  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: MoonpetalColors.softPink,
          child: const Icon(
            Icons.local_florist,
            size: 40,
            color: MoonpetalColors.deepPink,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Welcome to Moonpetal',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: MoonpetalColors.deepPink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Nothing logged yet. Start by marking today as a period day, or by '
          'logging how you feel.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        Text(
          'Today, ${formatLongDate(today)}',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// A dialog that edits a text value, or removes the field altogether.
class _TextCorrectionDialog extends StatefulWidget {
  const _TextCorrectionDialog({
    required this.title,
    required this.label,
    this.initialValue,
    this.fieldKey = const Key('correctionField'),
    this.maxLines = 3,
  });

  final String title;
  final String label;
  final String? initialValue;
  final Key fieldKey;
  final int maxLines;

  @override
  State<_TextCorrectionDialog> createState() => _TextCorrectionDialogState();
}

class _TextCorrectionDialogState extends State<_TextCorrectionDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('correctionDialog'),
      title: Text(widget.title),
      content: TextField(
        key: widget.fieldKey,
        controller: _controller,
        autofocus: true,
        maxLines: widget.maxLines,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('deleteCorrection'),
          onPressed: () =>
              Navigator.pop(context, (value: null, delete: true)),
          child: const Text('Delete'),
        ),
        FilledButton(
          key: const Key('saveCorrection'),
          onPressed: () =>
              Navigator.pop(context, (value: _controller.text, delete: false)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// A dialog that changes or clears a previously logged flow level.
class _FlowCorrectionDialog extends StatelessWidget {
  const _FlowCorrectionDialog({required this.current});

  final FlowLevel? current;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('correctionDialog'),
      title: const Text('Correct flow level'),
      content: Wrap(
        spacing: 8,
        children: [
          for (final level in FlowLevel.values)
            FilterChip(
              key: Key('correction-flow-${level.name}'),
              label: Text(level.label),
              selected: level == current,
              onSelected: (_) => Navigator.pop(
                context,
                (level: level, delete: false),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('deleteCorrection'),
          onPressed: () =>
              Navigator.pop(context, (level: null, delete: true)),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

/// Shows every saved value on a day, newest last, with its timestamp.
class _HistoryDialog extends StatelessWidget {
  const _HistoryDialog({
    required this.day,
    required this.records,
    required this.onDeleteEntry,
  });

  final DateTime day;
  final List<HistoryValue> records;
  final VoidCallback onDeleteEntry;

  @override
  Widget build(BuildContext context) {
    final currentByField = <String, HistoryValue>{
      for (final value in records) value.field: value,
    };
    return AlertDialog(
      key: const Key('historyDialog'),
      title: const Text('Edit history'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formatLongDate(day)),
          const SizedBox(height: 8),
          for (final value in records.reversed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${_describeHistoryValue(value)} — '
                '${_historyTimeFormat.format(value.at)}'
                '${identical(value, currentByField[value.field]) ? ' (current)' : ''}',
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('deleteEntryButton'),
          onPressed: onDeleteEntry,
          child: const Text('Delete entry'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Plain-language description of one saved value in the history dialog.
String _describeHistoryValue(HistoryValue value) {
  final saved = value.value;
  if (value.field == noteKey) {
    return saved == null ? 'Note deleted' : 'Note: $saved';
  }
  if (value.field == flowLevelKey) {
    if (saved == null) return 'Flow level cleared';
    return '${FlowLevel.values.asNameMap()[saved]?.label ?? saved} flow';
  }
  if (value.field == periodDayKey) {
    return saved == true ? 'Marked as period day' : 'Period day removed';
  }
  if (value.field.startsWith(symptomHistoryPrefix)) {
    final name = value.field.substring(symptomHistoryPrefix.length);
    return saved == null ? '$name removed' : '$name: $saved';
  }
  if (value.field.startsWith(tagHistoryPrefix)) {
    final name = value.field.substring(tagHistoryPrefix.length);
    return saved == null ? 'Tag $name removed' : 'Tag $name added';
  }
  return '$saved';
}
