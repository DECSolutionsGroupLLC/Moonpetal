import 'package:flutter_test/flutter_test.dart';

import 'package:moonpetal/src/cycles.dart';
import 'package:moonpetal/src/log_entries.dart';
import 'package:moonpetal/src/periods.dart';

void main() {
  group('computeCycleHistory', () {
    test('regular cycles count the days from one start to the next', () {
      final periods = <Period>[
        Period(start: DateTime(2026, 1, 1)),
        Period(start: DateTime(2026, 1, 29)),
        Period(start: DateTime(2026, 2, 26)),
      ];

      final history = computeCycleHistory(periods);

      expect(history.map((cycle) => cycle.cycleLengthDays), <int>[28, 28]);
    });

    test('irregular cycles keep each start-to-start count separate', () {
      final periods = <Period>[
        Period(start: DateTime(2026, 3, 1)),
        Period(start: DateTime(2026, 3, 29)), // 28 days
        Period(start: DateTime(2026, 4, 24)), // 26 days
        Period(start: DateTime(2026, 5, 23)), // 29 days
      ];

      final history = computeCycleHistory(periods);

      expect(history.map((cycle) => cycle.cycleLengthDays), <int>[28, 26, 29]);
    });

    test('counts across month and year boundaries and accepts unsorted input', () {
      final periods = <Period>[
        Period(start: DateTime(2027, 1, 26)),
        Period(start: DateTime(2026, 12, 29)),
        Period(start: DateTime(2026, 11, 30)),
      ];

      final history = computeCycleHistory(periods);

      expect(history.map((cycle) => cycle.start), <DateTime>[
        DateTime(2026, 11, 30),
        DateTime(2026, 12, 29),
      ]);
      expect(history.map((cycle) => cycle.cycleLengthDays), <int>[29, 28]);
    });

    test('a cycle carries the bleed duration of the period that began it', () {
      final periods = <Period>[
        Period(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 5)),
        Period(start: DateTime(2026, 1, 29), end: DateTime(2026, 2, 2)),
      ];

      final history = computeCycleHistory(periods);

      expect(history.single.bleedDurationDays, 5);
    });

    test('an open starting period has no recorded bleed duration', () {
      final periods = <Period>[
        Period(start: DateTime(2026, 1, 1)),
        Period(start: DateTime(2026, 1, 29)),
      ];

      final history = computeCycleHistory(periods);

      expect(history.single.cycleLengthDays, 28);
      expect(history.single.bleedDurationDays, isNull);
    });

    test('the most recent period has no completed cycle of its own', () {
      final periods = <Period>[
        Period(start: DateTime(2026, 1, 1)),
        Period(start: DateTime(2026, 1, 29)),
        Period(start: DateTime(2026, 2, 26)),
      ];

      final history = computeCycleHistory(periods);

      expect(history, hasLength(2));
      expect(history.map((cycle) => cycle.start), <DateTime>[
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 29),
      ]);
    });

    test('fewer than two periods produce no history', () {
      expect(computeCycleHistory(const <Period>[]), isEmpty);
      expect(
        computeCycleHistory(<Period>[Period(start: DateTime(2026, 1, 1))]),
        isEmpty,
      );
    });
  });

  group('CycleDocument', () {
    test('cycle history is derived from logged days and explicit ends', () {
      final document = <String, Object?>{}
          .withPeriodDay(DateTime(2026, 1, 1))
          .withPeriodDay(DateTime(2026, 1, 2))
          .withPeriodDay(DateTime(2026, 1, 29))
          .withPeriodDay(DateTime(2026, 1, 30));

      final withEnd = document.withPeriodEnd(
        Period(start: DateTime(2026, 1, 1)),
        DateTime(2026, 1, 2),
      );

      final history = withEnd.cycleHistory;
      expect(history, hasLength(1));
      expect(history.single.cycleLengthDays, 28);
      expect(history.single.bleedDurationDays, 2);
    });
  });
}
