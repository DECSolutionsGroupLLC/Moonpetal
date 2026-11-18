import 'package:flutter/material.dart';

import 'estimate.dart';

/// The key holding reminder Settings inside the one on-device document.
const String remindersKey = 'reminders';

const String _upcomingPeriodEnabledKey = 'upcomingPeriodEnabled';
const String _dailyLoggingEnabledKey = 'dailyLoggingEnabled';
const String _dailyLoggingHourKey = 'dailyLoggingHour';
const String _dailyLoggingMinuteKey = 'dailyLoggingMinute';

/// Days before the start of the estimated window for the period reminder.
const int periodReminderLeadDays = 1;

/// Hour used for the one-off upcoming-period reminder.
const int periodReminderHour = 9;

/// A sensible first choice for the configurable daily logging prompt.
const TimeOfDay defaultDailyLoggingTime = TimeOfDay(hour: 20, minute: 0);

/// User-owned reminder settings. Off until the user opts in, and stored with
/// the rest of Settings so an export carries the whole setup.
class ReminderSettings {
  const ReminderSettings({
    this.upcomingPeriodEnabled = false,
    this.dailyLoggingEnabled = false,
    TimeOfDay? dailyLoggingTime,
  }) : dailyLoggingTime = dailyLoggingTime ?? defaultDailyLoggingTime;

  /// Whether to remind before the next estimated period window.
  final bool upcomingPeriodEnabled;

  /// Whether to prompt for a log entry every day.
  final bool dailyLoggingEnabled;

  /// Local time of day for the daily logging prompt.
  final TimeOfDay dailyLoggingTime;

  ReminderSettings copyWith({
    bool? upcomingPeriodEnabled,
    bool? dailyLoggingEnabled,
    TimeOfDay? dailyLoggingTime,
  }) {
    return ReminderSettings(
      upcomingPeriodEnabled: upcomingPeriodEnabled ?? this.upcomingPeriodEnabled,
      dailyLoggingEnabled: dailyLoggingEnabled ?? this.dailyLoggingEnabled,
      dailyLoggingTime: dailyLoggingTime ?? this.dailyLoggingTime,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        _upcomingPeriodEnabledKey: upcomingPeriodEnabled,
        _dailyLoggingEnabledKey: dailyLoggingEnabled,
        _dailyLoggingHourKey: dailyLoggingTime.hour,
        _dailyLoggingMinuteKey: dailyLoggingTime.minute,
      };

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings &&
      other.upcomingPeriodEnabled == upcomingPeriodEnabled &&
      other.dailyLoggingEnabled == dailyLoggingEnabled &&
      other.dailyLoggingTime == dailyLoggingTime;

  @override
  int get hashCode => Object.hash(
        upcomingPeriodEnabled,
        dailyLoggingEnabled,
        dailyLoggingTime,
      );
}

int _storedInt(Object? value, int fallback) =>
    value is int ? value : fallback;

/// Typed access to the reminder settings stored with the other Settings.
extension ReminderDocument on Map<String, Object?> {
  ReminderSettings get reminderSettings {
    final stored = this[remindersKey];
    if (stored is! Map<String, Object?>) return const ReminderSettings();
    return ReminderSettings(
      upcomingPeriodEnabled: stored[_upcomingPeriodEnabledKey] == true,
      dailyLoggingEnabled: stored[_dailyLoggingEnabledKey] == true,
      dailyLoggingTime: TimeOfDay(
        hour: _storedInt(
          stored[_dailyLoggingHourKey],
          defaultDailyLoggingTime.hour,
        ),
        minute: _storedInt(
          stored[_dailyLoggingMinuteKey],
          defaultDailyLoggingTime.minute,
        ),
      ),
    );
  }

  /// A copy of this document with new reminder settings.
  Map<String, Object?> withReminderSettings(ReminderSettings settings) =>
      <String, Object?>{...this, remindersKey: settings.toJson()};
}

/// The reminders the device should schedule, derived from the user's Settings
/// and the current Estimate. This is the boundary between Moonpetal's reminder
/// logic and the platform's notification service.
class ReminderPlan {
  const ReminderPlan({this.upcomingPeriodAt, this.dailyLoggingTime});

  /// When to show the one-off upcoming-period reminder, if enabled and if an
  /// Estimate exists to base it on.
  final DateTime? upcomingPeriodAt;

  /// Recurring time for the daily logging prompt, if enabled.
  final TimeOfDay? dailyLoggingTime;

  @override
  bool operator ==(Object other) =>
      other is ReminderPlan &&
      other.upcomingPeriodAt == upcomingPeriodAt &&
      other.dailyLoggingTime == dailyLoggingTime;

  @override
  int get hashCode => Object.hash(upcomingPeriodAt, dailyLoggingTime);
}

/// Builds the device-facing reminder plan. The period reminder follows the
/// earliest edge of the Estimate's range rather than a promised single date;
/// the logging prompt repeats at the user's chosen local time.
ReminderPlan planReminders(
  ReminderSettings settings,
  NextPeriodEstimate? estimate,
) {
  final reminderDay = estimate == null
      ? null
      : addCalendarDays(estimate.rangeStart, -periodReminderLeadDays);
  return ReminderPlan(
    upcomingPeriodAt: settings.upcomingPeriodEnabled && reminderDay != null
        ? DateTime(
            reminderDay.year,
            reminderDay.month,
            reminderDay.day,
            periodReminderHour,
          )
        : null,
    dailyLoggingTime: settings.dailyLoggingEnabled
        ? settings.dailyLoggingTime
        : null,
  );
}

/// The outward boundary for notifications. Implementations replace all
/// pending reminders to match each plan they receive.
abstract interface class ReminderScheduler {
  Future<void> sync(ReminderPlan plan);
}

/// Used everywhere local notifications are not available. It does nothing —
/// the interface makes the unsupported case explicit rather than silently
/// failing inside the UI.
class NoOpReminderScheduler implements ReminderScheduler {
  const NoOpReminderScheduler();

  @override
  Future<void> sync(ReminderPlan plan) async {}
}
