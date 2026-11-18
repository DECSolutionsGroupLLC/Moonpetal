import 'package:moonpetal/src/clock.dart';
import 'package:moonpetal/src/storage.dart';

class FixedClock implements Clock {
  const FixedClock(this.fixedNow);

  final DateTime fixedNow;

  @override
  DateTime now() => fixedNow;
}

/// A clock a test can advance between actions, so history timestamps differ.
class SettableClock implements Clock {
  SettableClock(this.fixedNow);

  DateTime fixedNow;

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

/// Two stores sharing one backing map model two app launches against the same
/// on-device data, without doing real file I/O inside a widget test.
class SharedInMemoryAppStore implements AppStore {
  SharedInMemoryAppStore(this.backing);

  final Map<String, Object?> backing;

  @override
  Future<Map<String, Object?>> read() async =>
      Map<String, Object?>.unmodifiable(backing);

  @override
  Future<void> write(Map<String, Object?> document) async {
    backing
      ..clear()
      ..addAll(document);
  }
}
