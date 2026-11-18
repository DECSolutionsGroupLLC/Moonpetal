import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminders.dart';

/// The Android-only adapter that turns a [ReminderPlan] into local
/// notifications. It is never constructed on other platforms: [main] wires it
/// up only on Android, and everything else uses [NoOpReminderScheduler].
///
/// All data it handles is derived from the Estimate already on the device. It
/// makes no network calls and needs no install-time permissions.
class AndroidReminderScheduler implements ReminderScheduler {
  AndroidReminderScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const int _upcomingPeriodId = 1;
  static const int _dailyLoggingId = 2;
  static const String _channelId = 'moonpetal_reminders';
  static const String _channelName = 'Moonpetal reminders';
  static const String _channelDescription =
      'Local reminders configured on this device.';

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initializing;

  Future<void> _initialize() {
    final pending = _initializing;
    if (pending != null) return pending;

    final initializing = () async {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      tz_data.initializeTimeZones();
      try {
        final local = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(local.identifier));
      } catch (_) {
        // Unknown zone names fall back to the database's UTC location, which
        // still schedules locally; the prompt is never a precise medical time.
      }
    }();
    _initializing = initializing;
    // A failed first attempt must not poison every later sync.
    initializing.catchError((_) => _initializing = null);
    return initializing;
  }

  Future<void> _requestPermissionIfNeeded(ReminderPlan plan) async {
    if (plan.upcomingPeriodAt == null && plan.dailyLoggingTime == null) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
  );

  @override
  Future<void> sync(ReminderPlan plan) async {
    await _initialize();
    await _requestPermissionIfNeeded(plan);
    await _plugin.cancel(id: _upcomingPeriodId);
    await _plugin.cancel(id: _dailyLoggingId);

    final periodAt = plan.upcomingPeriodAt;
    if (periodAt != null && periodAt.isAfter(DateTime.now())) {
      await _plugin.zonedSchedule(
        id: _upcomingPeriodId,
        title: 'Your period may be coming',
        body: 'The start of your estimated window is near. This is an '
            'estimate, not an exact date.',
        scheduledDate: tz.TZDateTime.from(periodAt, tz.local),
        notificationDetails: _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }

    final dailyAt = plan.dailyLoggingTime;
    if (dailyAt != null) {
      final now = DateTime.now();
      var scheduled = DateTime(
        now.year,
        now.month,
        now.day,
        dailyAt.hour,
        dailyAt.minute,
      );
      if (!scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      await _plugin.zonedSchedule(
        id: _dailyLoggingId,
        title: 'A moment to log',
        body: 'Take a moment to record how you feel today.',
        scheduledDate: tz.TZDateTime.from(scheduled, tz.local),
        notificationDetails: _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }
}
