import 'package:flutter/material.dart';

import 'cycles.dart';
import 'log_entries.dart';
import 'periods.dart';
import 'theme.dart';

/// Plain-language explanation of how Cycle length is counted.
const String cycleLengthExplanation =
    'Cycle length counts the days from one period start to the next period '
    'start.';

String _daysLabel(int days) => '$days ${days == 1 ? 'day' : 'days'}';

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
    required this.todayFlowLevel,
    required this.onLogPeriodDay,
    required this.onSetPeriodStart,
    required this.onSetFlowLevel,
    required this.onEndPeriod,
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

  /// The Flow level saved for today, if the user has recorded one.
  final FlowLevel? todayFlowLevel;
  final VoidCallback onLogPeriodDay;

  /// Records a user-chosen day as the start of a period.
  final ValueChanged<DateTime> onSetPeriodStart;

  /// Records a Flow level for today; null clears it.
  final ValueChanged<FlowLevel?> onSetFlowLevel;

  /// Records the day a period ended.
  final void Function(Period period, DateTime end) onEndPeriod;

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
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.local_florist,
                      color: MoonpetalColors.deepPink,
                    ),
                    title: Text(formatLongDate(entry.date)),
                    subtitle: const Text('Period day'),
                  ),
                ),
                if (flowDays.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Flow levels', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...flowDays.map(
                    (entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.water_drop,
                        color: MoonpetalColors.deepPink,
                      ),
                      title: Text(formatLongDate(entry.date)),
                      subtitle: Text('${entry.flowLevel!.label} flow'),
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
