import 'package:flutter_test/flutter_test.dart';

import 'package:moonpetal/src/log_entries.dart';
import 'package:moonpetal/src/periods.dart';

void main() {
  group('groupPeriodDays', () {
    test('an empty set of days has no periods', () {
      expect(groupPeriodDays(const <DateTime>[]), isEmpty);
    });

    test('unsorted, duplicate consecutive days form one open period', () {
      final periods = groupPeriodDays(<DateTime>[
        DateTime(2026, 11, 18),
        DateTime(2026, 11, 16),
        DateTime(2026, 11, 17),
        DateTime(2026, 11, 16, 14),
      ]);

      expect(periods, hasLength(1));
      expect(periods.single.start, DateTime(2026, 11, 16));
      expect(periods.single.isOpen, isTrue);
      expect(periods.single.bleedDurationDays, isNull);
    });

    test('a gap starts a separate period', () {
      final periods = groupPeriodDays(<DateTime>[
        DateTime(2026, 12, 2),
        DateTime(2026, 11, 30),
        DateTime(2026, 11, 29),
      ]);

      expect(periods, hasLength(2));
      expect(periods.map((period) => period.start), <DateTime>[
        DateTime(2026, 11, 29),
        DateTime(2026, 12, 2),
      ]);
      expect(periods.every((period) => period.isOpen), isTrue);
    });

    test('month and year boundaries do not split a run', () {
      final periods = groupPeriodDays(<DateTime>[
        DateTime(2026, 12, 31),
        DateTime(2027, 1, 1),
      ]);

      expect(periods, hasLength(1));
      expect(periods.single.start, DateTime(2026, 12, 31));
    });

    test('an explicit end is attached to the period with that start', () {
      final periods = groupPeriodDays(
        <DateTime>[DateTime(2026, 11, 18), DateTime(2026, 11, 19)],
        ends: <String, DateTime>{'2026-11-18': DateTime(2026, 11, 20)},
      );

      expect(periods.single.isOpen, isFalse);
      expect(periods.single.end, DateTime(2026, 11, 20));
      expect(periods.single.bleedDurationDays, 3);
    });
  });

  group('Period', () {
    test('bleed duration counts both the start and end day', () {
      final period = Period(
        start: DateTime(2026, 11, 18),
        end: DateTime(2026, 11, 20),
      );

      expect(period.bleedDurationDays, 3);
    });

    test('a one-day period has a bleed duration of one day', () {
      final day = DateTime(2026, 11, 18);
      expect(Period(start: day, end: day).bleedDurationDays, 1);
    });
  });

  group('PeriodDocument', () {
    test('periods are derived from logged period days', () {
      final document = <String, Object?>{}
          .withPeriodDay(DateTime(2026, 11, 18))
          .withPeriodDay(DateTime(2026, 11, 19));

      expect(document.periods, hasLength(1));
      expect(document.periods.single.bleedDurationDays, isNull);
    });

    test('recording an end persists it and is preserved by later writes', () {
      final start = DateTime(2026, 11, 18);
      final ended = <String, Object?>{}
          .withPeriodDay(start)
          .withPeriodDay(DateTime(2026, 11, 19))
          .withPeriodEnd(Period(start: start), DateTime(2026, 11, 20));

      expect(ended.periods.single.bleedDurationDays, 3);

      final withAnotherDay = ended.withPeriodDay(DateTime(2026, 11, 25));
      expect(withAnotherDay.periods, hasLength(2));
      expect(withAnotherDay.periods.first.bleedDurationDays, 3);
      expect(withAnotherDay.periods.last.isOpen, isTrue);
    });

    test('an end before the start is rejected', () {
      final document = <String, Object?>{}.withPeriodDay(
        DateTime(2026, 11, 18),
      );

      expect(
        () => document.withPeriodEnd(
          Period(start: DateTime(2026, 11, 18)),
          DateTime(2026, 11, 17),
        ),
        throwsArgumentError,
      );
    });

    test('unrelated document keys survive recording an end', () {
      final document = <String, Object?>{
        'settings': <String, Object?>{'theme': 'pink'},
      };

      final updated = document.withPeriodEnd(
        Period(start: DateTime(2026, 11, 18)),
        DateTime(2026, 11, 20),
      );

      expect(updated['settings'], equals(document['settings']));
    });
  });
}
