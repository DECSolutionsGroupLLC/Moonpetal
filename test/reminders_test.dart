import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moonpetal/app.dart';
import 'package:moonpetal/src/log_entries.dart';
import 'package:moonpetal/src/reminders.dart';
import 'package:moonpetal/src/reminders_view.dart';
import 'package:moonpetal/src/storage.dart';

import 'helpers/fakes.dart';

class RecordingReminderScheduler implements ReminderScheduler {
  final List<ReminderPlan> plans = <ReminderPlan>[];

  @override
  Future<void> sync(ReminderPlan plan) async => plans.add(plan);
}

// ignore: deprecated_member_use
class NoNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw StateError('Moonpetal must never make a network call.');
  }
}

void main() {
  final today = DateTime(2026, 3, 10, 9);
  final regularStarts = <DateTime>[
    DateTime(2026, 1, 1),
    DateTime(2026, 1, 29),
    DateTime(2026, 2, 26),
  ];

  var launch = 0;

  Map<String, Object?> documentWithPeriodStarts(Iterable<DateTime> starts) {
    var document = <String, Object?>{};
    for (final start in starts) {
      document = document.withPeriodDay(start);
    }
    return document;
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    AppStore? store,
    ReminderScheduler? scheduler,
    bool notificationsAvailable = true,
    Map<String, Object?>? document,
  }) async {
    await tester.pumpWidget(
      MoonpetalApp(
        key: ValueKey(launch++),
        clock: FixedClock(today),
        store: store ?? InMemoryAppStore(document: document),
        reminderScheduler: scheduler ?? const NoOpReminderScheduler(),
        notificationsAvailable: notificationsAvailable,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    final button = find.byKey(const Key('reminderSettingsButton'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> toggle(WidgetTester tester, Key key) async {
    final control = find.byKey(key);
    await tester.ensureVisible(control);
    await tester.pumpAndSettle();
    await tester.tap(control);
    await tester.pumpAndSettle();
  }

  Future<void> setLoggingTime(
    WidgetTester tester, {
    required String hour,
    required String minute,
  }) async {
    final button = find.byKey(const Key('dailyLoggingTimeButton'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    Future<void> enter(String label, String value) => tester.enterText(
          find.descendant(
            of: find.bySemanticsLabel(label),
            matching: find.byType(EditableText),
          ),
          value,
        );
    await enter('Hour', hour);
    await enter('Minute', minute);
    final am = find.text('AM');
    if (am.evaluate().isNotEmpty) await tester.tap(am);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  testWidgets('the upcoming-period reminder can be enabled and follows the '
      'Estimate', (tester) async {
    final scheduler = RecordingReminderScheduler();
    await pumpApp(
      tester,
      scheduler: scheduler,
      document: documentWithPeriodStarts(regularStarts),
    );

    expect(scheduler.plans.last.upcomingPeriodAt, isNull);

    await openSettings(tester);
    expect(
      find.textContaining('Based on your Estimate'),
      findsOneWidget,
    );
    await toggle(tester, const Key('upcomingPeriodReminderSwitch'));

    expect(
      scheduler.plans.last.upcomingPeriodAt,
      DateTime(2026, 3, 24, 9),
    );
    expect(scheduler.plans.last.dailyLoggingTime, isNull);
  });

  testWidgets('the daily logging prompt can be enabled and given a time',
      (tester) async {
    final scheduler = RecordingReminderScheduler();
    final store = SharedInMemoryAppStore(
      documentWithPeriodStarts(regularStarts),
    );
    await pumpApp(tester, store: store, scheduler: scheduler);
    await openSettings(tester);
    await toggle(tester, const Key('dailyLoggingReminderSwitch'));
    await setLoggingTime(tester, hour: '7', minute: '30');

    expect(
      scheduler.plans.last.dailyLoggingTime,
      const TimeOfDay(hour: 7, minute: 30),
    );
    expect(scheduler.plans.last.upcomingPeriodAt, isNull);

    await pumpApp(tester, store: store, scheduler: scheduler);
    expect(
      scheduler.plans.last.dailyLoggingTime,
      const TimeOfDay(hour: 7, minute: 30),
    );
    await openSettings(tester);
    final daily = tester.widget<SwitchListTile>(
      find.byKey(const Key('dailyLoggingReminderSwitch')),
    );
    expect(daily.value, isTrue);
    expect(
      find.textContaining('07:30'),
      findsOneWidget,
    );
  });

  testWidgets('the Android-only note is shown where notifications are '
      'unavailable', (tester) async {
    final scheduler = RecordingReminderScheduler();
    await pumpApp(
      tester,
      scheduler: scheduler,
      notificationsAvailable: false,
      document: documentWithPeriodStarts(regularStarts),
    );

    // The limitation is visible before the user goes looking for it.
    expect(
      find.text('Reminder settings (Android-only)'),
      findsOneWidget,
    );

    await openSettings(tester);

    expect(
      find.byKey(const Key('androidOnlyNotice')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ReminderSettingsView),
        matching: find.textContaining('Notifications are Android-only'),
      ),
      findsOneWidget,
    );
    expect(scheduler.plans.last.upcomingPeriodAt, isNull);
    expect(scheduler.plans.last.dailyLoggingTime, isNull);
  });

  testWidgets('an enabled period reminder waits for an Estimate instead of '
      'inventing a date', (tester) async {
    final scheduler = RecordingReminderScheduler();
    await pumpApp(
      tester,
      scheduler: scheduler,
      document: documentWithPeriodStarts(<DateTime>[DateTime(2026, 2, 1)]),
    );
    await openSettings(tester);
    await toggle(tester, const Key('upcomingPeriodReminderSwitch'));

    expect(scheduler.plans.last.upcomingPeriodAt, isNull);
    expect(
      find.textContaining('at least two cycles'),
      findsOneWidget,
    );
  });

  testWidgets('configuring reminders sends nothing off the device', (
    tester,
  ) async {
    // ignore: deprecated_member_use
    HttpOverrides.global = NoNetworkHttpOverrides();
    addTearDown(() {
      // ignore: deprecated_member_use
      HttpOverrides.global = null;
    });

    final store = SharedInMemoryAppStore(
      documentWithPeriodStarts(regularStarts),
    );
    await pumpApp(tester, store: store);
    await openSettings(tester);
    await toggle(tester, const Key('upcomingPeriodReminderSwitch'));
    await toggle(tester, const Key('dailyLoggingReminderSwitch'));

    expect(tester.takeException(), isNull);
    final saved = store.backing.reminderSettings;
    expect(saved.upcomingPeriodEnabled, isTrue);
    expect(saved.dailyLoggingEnabled, isTrue);
  });

  testWidgets('the reminder settings screen fits a phone-sized portrait '
      'viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpApp(
      tester,
      document: documentWithPeriodStarts(regularStarts),
      notificationsAvailable: false,
    );
    await openSettings(tester);

    final notice = find.byKey(const Key('androidOnlyNotice'));
    final rect = tester.getRect(notice);
    expect(tester.takeException(), isNull);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(390));
  });
}
