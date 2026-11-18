import 'dart:io';

import 'package:flutter/material.dart';

import 'app.dart';
import 'src/android_notifications.dart';
import 'src/reminders.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Local notifications are an Android capability. Other builds keep the same
  // settings, but never initialise a notification plugin or claim to deliver.
  final android = Platform.isAndroid;
  runApp(
    MoonpetalApp(
      notificationsAvailable: android,
      reminderScheduler: android
          ? AndroidReminderScheduler()
          : const NoOpReminderScheduler(),
    ),
  );
}
