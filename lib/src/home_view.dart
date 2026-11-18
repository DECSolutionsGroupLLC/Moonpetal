import 'package:flutter/material.dart';

import 'log_entries.dart';
import 'theme.dart';

/// The daily screen: log today in one tap and review logged period days.
class HomeView extends StatelessWidget {
  const HomeView({
    super.key,
    required this.today,
    required this.hasLogEntries,
    required this.periodDays,
    required this.onLogPeriodDay,
  });

  final DateTime today;

  /// First run means no log entries at all, including entries that are not
  /// period days, so this is deliberately separate from [periodDays].
  final bool hasLogEntries;
  final List<LogEntry> periodDays;
  final VoidCallback onLogPeriodDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTodayLogged = periodDays.containsDay(today);

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
                  isTodayLogged ? 'Today is logged' : 'Log today as a period day',
                ),
              ),
              if (hasLogEntries) ...[
                const SizedBox(height: 32),
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
