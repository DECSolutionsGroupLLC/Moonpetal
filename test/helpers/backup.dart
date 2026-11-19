import 'package:flutter/material.dart';

import 'package:moonpetal/src/backup.dart';
import 'package:moonpetal/src/fertility.dart';
import 'package:moonpetal/src/log_entries.dart';
import 'package:moonpetal/src/periods.dart';
import 'package:moonpetal/src/reminders.dart';

/// A document with every kind of data and Settings the app currently stores,
/// including a correction so edit history is present too.
Map<String, Object?> richBackupDocument() {
  final first = DateTime(2026, 1, 1);
  final second = DateTime(2026, 1, 29);

  var document = <String, Object?>{}
      .withPeriodDay(first)
      .withFlowLevel(first, FlowLevel.heavy)
      .withLoggedSymptom(first, 'Cramps', value: 'severe')
      .withNote(first, 'First day', at: DateTime(2026, 1, 1, 10))
      .withTag(first, 'busy')
      .withPeriodDay(second)
      .withCustomSymptomName('Dizziness')
      .withTagName('busy')
      .withFertilityViewEnabled(true)
      .withReminderSettings(
        const ReminderSettings(
          upcomingPeriodEnabled: true,
          dailyLoggingEnabled: true,
          dailyLoggingTime: TimeOfDay(hour: 21, minute: 30),
        ),
      );
  document = document.withPeriodEnd(
    document.periods.first,
    DateTime(2026, 1, 4),
  );
  return document.withNote(
    first,
    'Corrected note',
    at: DateTime(2026, 1, 2, 9),
  );
}

/// An in-memory stand-in for the native save/pick dialogs. Nothing here can
/// reach the network or a real filesystem.
class FakeBackupGateway implements BackupGateway {
  String? savedContents;
  PickedBackup? picked;
  bool saveCancelled = false;
  bool loadCancelled = false;

  @override
  Future<String?> save(String suggestedName, String contents) async {
    if (saveCancelled) return null;
    savedContents = contents;
    return '/backups/$suggestedName';
  }

  @override
  Future<PickedBackup?> load() async => loadCancelled ? null : picked;
}
