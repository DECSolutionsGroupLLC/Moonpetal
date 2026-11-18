import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// The key under which log entries live in the stored document.
const String logEntriesKey = 'logEntries';

/// User-defined symptom names, stored once and reused on later days.
const String symptomNamesKey = 'symptomNames';

/// User-created tag labels, stored once and reused on later days.
const String tagNamesKey = 'tagNames';

/// Whether the opt-in fertility view is shown. Absent means off.
const String fertilityViewEnabledKey = 'fertilityViewEnabled';

/// Typed access to the document so callers don't repeat its string keys.
extension AppDocument on Map<String, Object?> {
  /// First run means no log entries, even if Settings have been stored.
  bool get hasLogEntries {
    final entries = this[logEntriesKey];
    return entries is List && entries.isNotEmpty;
  }
}

/// The single on-device storage boundary.
///
/// All log entries and Settings are persisted in this one JSON document.
/// Later features add their typed accessors on top of this boundary rather
/// than opening another store. A missing document means first run.
abstract interface class AppStore {
  /// Reads the whole document, returning an empty map on first run.
  Future<Map<String, Object?>> read();

  /// Replaces the whole document with [document].
  Future<void> write(Map<String, Object?> document);
}

/// Persists the document as a human-readable JSON file on the device.
class JsonFileAppStore implements AppStore {
  const JsonFileAppStore({this.documentsDirectory});

  static const fileName = 'moonpetal.json';

  final Future<Directory> Function()? documentsDirectory;

  Future<File> _resolveFile() async {
    final directory = await (documentsDirectory ??
        getApplicationDocumentsDirectory)();
    return File(
      '${directory.path}${Platform.pathSeparator}$fileName',
    );
  }

  @override
  Future<Map<String, Object?>> read() async {
    final file = await _resolveFile();
    if (!await file.exists()) return <String, Object?>{};

    final contents = await file.readAsString();
    if (contents.trim().isEmpty) return <String, Object?>{};

    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Moonpetal data file must contain a JSON object.');
    }
    return decoded;
  }

  @override
  Future<void> write(Map<String, Object?> document) async {
    final file = await _resolveFile();
    final encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(document));
  }
}
