import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moonpetal/src/reminders.dart';
import 'package:moonpetal/src/storage.dart';

import 'helpers/fakes.dart';

void main() {
  test('reminders are off by default until the user enables them', () {
    const document = <String, Object?>{};

    expect(document.reminderSettings.upcomingPeriodEnabled, isFalse);
    expect(document.reminderSettings.dailyLoggingEnabled, isFalse);
    expect(
      document.reminderSettings.dailyLoggingTime,
      const TimeOfDay(hour: 20, minute: 0),
    );
  });

  test('reminder settings persist through the on-device document', () async {
    const saved = ReminderSettings(
      upcomingPeriodEnabled: true,
      dailyLoggingEnabled: true,
      dailyLoggingTime: TimeOfDay(hour: 7, minute: 30),
    );
    final store = InMemoryAppStore();
    await store.write(<String, Object?>{}.withReminderSettings(saved));

    expect((await store.read()).reminderSettings, saved);
  });

  test('reminder settings are inside the exportable local JSON document',
      () async {
    final directory = await Directory.systemTemp.createTemp('moonpetal-rem-');
    addTearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    final store = JsonFileAppStore(
      documentsDirectory: () async => directory,
    );
    await store.write(
      <String, Object?>{}.withReminderSettings(
        const ReminderSettings(
          upcomingPeriodEnabled: true,
          dailyLoggingEnabled: true,
          dailyLoggingTime: TimeOfDay(hour: 6, minute: 45),
        ),
      ),
    );

    final file = File(
      '${directory.path}${Platform.pathSeparator}${JsonFileAppStore.fileName}',
    );
    final exported = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final reminders = exported[remindersKey] as Map<String, dynamic>;

    expect(reminders['upcomingPeriodEnabled'], isTrue);
    expect(reminders['dailyLoggingEnabled'], isTrue);
    expect(reminders['dailyLoggingHour'], 6);
    expect(reminders['dailyLoggingMinute'], 45);
    expect((await store.read()).reminderSettings.dailyLoggingTime,
        const TimeOfDay(hour: 6, minute: 45));
  });
}
