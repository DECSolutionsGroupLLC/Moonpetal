import 'package:flutter_test/flutter_test.dart';

import 'package:moonpetal/src/log_entries.dart';
import 'package:moonpetal/src/storage.dart';

void main() {
  test('recording a period day leaves unrelated log entries intact', () {
    final document = <String, Object?>{
      logEntriesKey: <Object?>['an entry from a later slice'],
    };

    final updated = document.withPeriodDay(DateTime(2026, 11, 18));

    expect(updated[logEntriesKey], contains('an entry from a later slice'));
    expect(updated.periodDays, hasLength(1));
  });

  test('recording the same period day twice does not duplicate it', () {
    final day = DateTime(2026, 11, 18);
    final document = <String, Object?>{}.withPeriodDay(day);

    final updated = document.withPeriodDay(day);

    expect(updated.periodDays, hasLength(1));
    expect(updated.periodDays.containsDay(day), isTrue);
  });
}
