import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:moonpetal/src/log_entries.dart';
import 'package:moonpetal/src/storage.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('moonpetal-store-');
  });

  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  test('first run reads an empty document', () async {
    final store = JsonFileAppStore(documentsDirectory: () async => directory);

    expect(await store.read(), isEmpty);
  });

  test('the document persists as readable JSON across store instances',
      () async {
    final store = JsonFileAppStore(documentsDirectory: () async => directory);
    await store.write(<String, Object?>{
      logEntriesKey: <Object>['2026-11-18'],
      'settings': <String, Object?>{'theme': 'pink'},
    });

    final reopened = JsonFileAppStore(
      documentsDirectory: () async => directory,
    );
    expect(await reopened.read(), equals(await store.read()));

    final saved = File(
      '${directory.path}${Platform.pathSeparator}${JsonFileAppStore.fileName}',
    );
    expect(saved.existsSync(), isTrue);
    final contents = await saved.readAsString();
    expect(contents, contains('\n  '));
    final decoded = jsonDecode(contents) as Map<String, dynamic>;
    expect(decoded['settings']['theme'], 'pink');
  });

  test('a period day persists through a fresh store reading the saved JSON',
      () async {
    final day = DateTime(2026, 11, 18);
    final store = JsonFileAppStore(documentsDirectory: () async => directory);
    await store.write(<String, Object?>{}.withPeriodDay(day));

    final reopened = JsonFileAppStore(
      documentsDirectory: () async => directory,
    );
    final document = await reopened.read();

    expect(document.periodDays, hasLength(1));
    expect(document.periodDays.containsDay(day), isTrue);
  });

  test('edit history and its timestamps survive JSON persistence', () async {
    final day = DateTime(2026, 11, 18);
    final store = JsonFileAppStore(documentsDirectory: () async => directory);
    await store.write(
      <String, Object?>{}
          .withNote(day, 'Original', at: DateTime(2026, 11, 18, 8, 30))
          .withNote(day, 'Corrected', at: DateTime(2026, 11, 18, 9, 15)),
    );

    final reopened = JsonFileAppStore(
      documentsDirectory: () async => directory,
    );
    final history = (await reopened.read()).editHistoryFor(day, noteKey);

    expect(
      history.map((record) => record.value),
      equals(['Original', 'Corrected']),
    );
    expect(history.first.at, DateTime(2026, 11, 18, 8, 30));
    expect(history.last.at, DateTime(2026, 11, 18, 9, 15));
  });
}
