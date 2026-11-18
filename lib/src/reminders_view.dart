import 'package:flutter/material.dart';

import 'estimate.dart';
import 'log_entries.dart';
import 'reminders.dart';
import 'theme.dart';

/// The local-only statement shown where the platform cannot deliver
/// notifications. It is deliberately about the notification capability, not a
/// claim that anything was sent anywhere.
const String androidOnlyNotice =
    'Notifications are Android-only. This build cannot deliver reminders, but '
    'your settings are still saved on this device and included in your export.';

/// Zero-padded 24-hour time so a configured prompt reads the same everywhere.
String formatReminderTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// Configuration screen for the on-device reminders. Nothing here contacts a
/// server; every change is persisted in the same document as the log entries.
class ReminderSettingsView extends StatelessWidget {
  const ReminderSettingsView({
    super.key,
    required this.settings,
    required this.notificationsAvailable,
    required this.estimate,
    required this.onUpdateSettings,
  });

  final ReminderSettings settings;
  final bool notificationsAvailable;
  final NextPeriodEstimate? estimate;
  /// Persists a change to the current stored Settings, so a screen opened
  /// earlier cannot overwrite a newer value with a stale copy.
  final ValueChanged<ReminderSettings Function(ReminderSettings)>
  onUpdateSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Reminder settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your reminders',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: MoonpetalColors.deepPink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Reminders are local and configured here on your device. No '
                'schedule or health information is sent anywhere.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              if (!notificationsAvailable) ...[
                Container(
                  key: const Key('androidOnlyNotice'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MoonpetalColors.softPink,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    androidOnlyNotice,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: MoonpetalColors.deepPink,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upcoming period',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: MoonpetalColors.deepPink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        estimate == null
                            ? 'Log at least two cycles to get an Estimate for '
                                'this reminder.'
                            : 'Based on your Estimate: around '
                                '${formatLongDate(estimate!.date)}. '
                                'The reminder comes before the estimated range '
                                'begins, and moves when your Estimate does.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SwitchListTile(
                        key: const Key('upcomingPeriodReminderSwitch'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Remind me before my period'),
                        subtitle: const Text(
                          'A one-off local reminder based on your Estimate.',
                        ),
                        value: settings.upcomingPeriodEnabled,
                        onChanged: (enabled) => onUpdateSettings(
                          (current) =>
                              current.copyWith(upcomingPeriodEnabled: enabled),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily logging prompt',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: MoonpetalColors.deepPink,
                        ),
                      ),
                      SwitchListTile(
                        key: const Key('dailyLoggingReminderSwitch'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Prompt me every day'),
                        subtitle: const Text(
                          'A recurring local nudge to log how you feel.',
                        ),
                        value: settings.dailyLoggingEnabled,
                        onChanged: (enabled) => onUpdateSettings(
                          (current) =>
                              current.copyWith(dailyLoggingEnabled: enabled),
                        ),
                      ),
                      OutlinedButton.icon(
                        key: const Key('dailyLoggingTimeButton'),
                        onPressed: () => _chooseTime(context),
                        icon: const Icon(Icons.schedule),
                        label: Text(
                          'Prompt time: '
                          '${formatReminderTime(settings.dailyLoggingTime)}',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Reminder Settings are stored on this device and included in '
                'your export.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: settings.dailyLoggingTime,
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (picked == null || !context.mounted) return;
    onUpdateSettings((current) => current.copyWith(dailyLoggingTime: picked));
  }
}
