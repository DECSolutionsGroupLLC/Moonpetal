import 'package:moonpetal/src/clock.dart';
import 'package:moonpetal/src/storage.dart';

class FixedClock implements Clock {
  const FixedClock(this.fixedNow);

  final DateTime fixedNow;

  @override
  DateTime now() => fixedNow;
}

class InMemoryAppStore implements AppStore {
  InMemoryAppStore({Map<String, Object?>? document})
    : _document = document ?? <String, Object?>{};

  Map<String, Object?> _document;

  @override
  Future<Map<String, Object?>> read() async =>
      Map<String, Object?>.unmodifiable(_document);

  @override
  Future<void> write(Map<String, Object?> document) async {
    _document = Map<String, Object?>.from(document);
  }
}
