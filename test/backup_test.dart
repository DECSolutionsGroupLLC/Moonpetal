import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moonpetal/app.dart';
import 'package:moonpetal/src/backup.dart';
import 'package:moonpetal/src/backup_view.dart';
import 'package:moonpetal/src/log_entries.dart';
import 'package:moonpetal/src/storage.dart';

import 'helpers/backup.dart';
import 'helpers/fakes.dart';

// ignore: deprecated_member_use
class NoNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw StateError('Export and restore must never make a network call.');
  }
}

void main() {
  final today = DateTime(2026, 3, 10, 9);
  var launch = 0;

  setUp(() => HttpOverrides.global = NoNetworkHttpOverrides());
  tearDown(() => HttpOverrides.global = null);

  Future<void> pumpApp(
    WidgetTester tester,
    Map<String, Object?> document, {
    AppStore? store,
    FakeBackupGateway? gateway,
  }) async {
    await tester.pumpWidget(
      MoonpetalApp(
        key: ValueKey(launch++),
        clock: FixedClock(today),
        store: store ?? InMemoryAppStore(document: document),
        backupGateway: gateway ?? FakeBackupGateway(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, Key key) async {
    final finder = find.byKey(key);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openBackup(WidgetTester tester) =>
      tapKey(tester, const Key('backupButton'));

  Future<void> closeBackup(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(BackupView))).pop();
    await tester.pumpAndSettle();
  }

  testWidgets('export writes one readable backup of every entry and setting', (
    tester,
  ) async {
    final document = richBackupDocument();
    final gateway = FakeBackupGateway();
    await pumpApp(tester, document, gateway: gateway);

    await openBackup(tester);
    await tapKey(tester, const Key('backupExportButton'));

    expect(gateway.savedContents, isNotNull);
    expect(gateway.savedContents, contains('\n  '));
    expect(decodeBackup(gateway.savedContents!), equals(document));
    expect(find.byKey(const Key('backupStatus')), findsOneWidget);
    expect(find.textContaining('Nothing was uploaded or shared'), findsOneWidget);
  });

  testWidgets('cancelling the save location writes nothing and changes no '
      'status', (tester) async {
    final gateway = FakeBackupGateway()..saveCancelled = true;
    await pumpApp(tester, richBackupDocument(), gateway: gateway);

    await openBackup(tester);
    await tapKey(tester, const Key('backupExportButton'));

    expect(gateway.savedContents, isNull);
    expect(find.byKey(const Key('backupStatus')), findsNothing);
  });

  testWidgets('a valid backup restores every entry, edit history and setting', (
    tester,
  ) async {
    final original = richBackupDocument();
    final sourceStore = InMemoryAppStore(document: original);
    final targetStore = InMemoryAppStore(
      document: <String, Object?>{}.withNote(
        DateTime(2026, 2, 1),
        'Old device note',
      ),
    );
    final gateway = FakeBackupGateway();

    await pumpApp(tester, const <String, Object?>{},
        store: sourceStore, gateway: gateway);
    await openBackup(tester);
    await tapKey(tester, const Key('backupExportButton'));
    final exported = gateway.savedContents!;

    gateway.picked = PickedBackup(name: 'moonpetal-backup.json', contents: exported);
    await pumpApp(tester, const <String, Object?>{},
        store: targetStore, gateway: gateway);
    await openBackup(tester);
    await tapKey(tester, const Key('backupRestoreButton'));

    expect(await targetStore.read(), equals(original));
    expect(
      find.textContaining('Restored from moonpetal-backup.json'),
      findsOneWidget,
    );

    await closeBackup(tester);
    expect(find.text('Corrected note'), findsOneWidget);
    expect(find.text('Old device note'), findsNothing);
    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const Key('fertilityViewSwitch')),
    );
    expect(toggle.value, isTrue);
  });

  testWidgets('an invalid file is reported clearly and leaves existing data '
      'intact', (tester) async {
    final original = richBackupDocument();
    final store = InMemoryAppStore(document: original);
    final gateway = FakeBackupGateway()
      ..picked = const PickedBackup(name: 'broken.json', contents: '{ broken');
    await pumpApp(tester, const <String, Object?>{},
        store: store, gateway: gateway);

    await openBackup(tester);
    await tapKey(tester, const Key('backupRestoreButton'));

    expect(find.textContaining('not valid JSON'), findsOneWidget);
    expect(find.textContaining('existing data was not changed'), findsOneWidget);
    expect(await store.read(), equals(original));

    await closeBackup(tester);
    expect(find.text('Corrected note'), findsOneWidget);
  });

  testWidgets('a JSON file that is not a Moonpetal backup is rejected without '
      'touching data', (tester) async {
    final original = richBackupDocument();
    final store = InMemoryAppStore(document: original);
    final gateway = FakeBackupGateway()
      ..picked = const PickedBackup(
        name: 'notes.json',
        contents: '{"hello":"world"}',
      );
    await pumpApp(tester, const <String, Object?>{},
        store: store, gateway: gateway);

    await openBackup(tester);
    await tapKey(tester, const Key('backupRestoreButton'));

    expect(find.textContaining('not a Moonpetal backup'), findsOneWidget);
    expect(await store.read(), equals(original));
  });

  testWidgets('cancelling the file picker restores nothing', (tester) async {
    final original = richBackupDocument();
    final store = InMemoryAppStore(document: original);
    final gateway = FakeBackupGateway()..loadCancelled = true;
    await pumpApp(tester, const <String, Object?>{},
        store: store, gateway: gateway);

    await openBackup(tester);
    await tapKey(tester, const Key('backupRestoreButton'));

    expect(find.byKey(const Key('backupStatus')), findsNothing);
    expect(await store.read(), equals(original));
  });

  testWidgets('export and restore are available on first run', (tester) async {
    await pumpApp(tester, const <String, Object?>{});

    expect(find.byKey(const Key('backupButton')), findsOneWidget);
    await openBackup(tester);
    expect(find.byKey(const Key('backupExportButton')), findsOneWidget);
    expect(find.byKey(const Key('backupRestoreButton')), findsOneWidget);
  });
}
