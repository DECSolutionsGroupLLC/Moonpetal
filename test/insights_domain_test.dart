import 'package:flutter_test/flutter_test.dart';

import 'package:moonpetal/src/cycles.dart';
import 'package:moonpetal/src/estimate.dart';
import 'package:moonpetal/src/insights.dart';
import 'package:moonpetal/src/log_entries.dart';
import 'package:moonpetal/src/periods.dart';

void main() {
  group('computePatternInsights', () {
    test('averages Cycle length and Bleed duration from known Cycles', () {
      final insights = computePatternInsights(
        cycles: <CycleRecord>[
          CycleRecord(
            start: DateTime(2026, 1, 1),
            cycleLengthDays: 28,
            bleedDurationDays: 5,
          ),
          CycleRecord(
            start: DateTime(2026, 1, 29),
            cycleLengthDays: 32,
            bleedDurationDays: 4,
          ),
          CycleRecord(
            start: DateTime(2026, 3, 2),
            cycleLengthDays: 30,
            bleedDurationDays: 6,
          ),
        ],
        periods: <Period>[
          Period(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 5)),
          Period(start: DateTime(2026, 1, 29), end: DateTime(2026, 2, 1)),
          Period(start: DateTime(2026, 3, 2), end: DateTime(2026, 3, 7)),
        ],
        logEntries: const <LogEntry>[],
      );

      expect(insights.cycleLength.lengths, <int>[28, 32, 30]);
      expect(insights.cycleLength.average, 30);
      expect(insights.cycleLength.summary, contains('about 30 days'));
      expect(insights.cycleLength.summary, contains('3 cycles'));

      expect(insights.bleedDuration.durations, <int>[5, 4, 6]);
      expect(insights.bleedDuration.average, 5);
      expect(insights.bleedDuration.summary, contains('about 5 days'));
      expect(insights.bleedDuration.summary, contains('3 periods'));
    });

    test('ignores Cycles without an end when averaging Bleed duration', () {
      final insights = computePatternInsights(
        cycles: <CycleRecord>[
          CycleRecord(
            start: DateTime(2026, 1, 1),
            cycleLengthDays: 28,
            bleedDurationDays: 5,
          ),
          CycleRecord(
            start: DateTime(2026, 1, 29),
            cycleLengthDays: 28,
          ),
        ],
        periods: <Period>[
          Period(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 5)),
          Period(start: DateTime(2026, 1, 29)),
        ],
        logEntries: const <LogEntry>[],
      );

      expect(insights.bleedDuration.durations, <int>[5]);
      expect(insights.bleedDuration.average, 5);
      expect(insights.cycleLength.average, 28);
    });

    test('counts symptom frequency in distinct days, most frequent first', () {
      final insights = computePatternInsights(
        cycles: const <CycleRecord>[],
        periods: const <Period>[],
        logEntries: <LogEntry>[
          LogEntry(
            date: DateTime(2026, 1, 1),
            isPeriodDay: true,
            symptoms: <LoggedSymptom>[
              const LoggedSymptom(name: 'Cramps'),
              const LoggedSymptom(name: 'Mood'),
            ],
          ),
          LogEntry(
            date: DateTime(2026, 1, 2),
            isPeriodDay: false,
            symptoms: <LoggedSymptom>[
              const LoggedSymptom(name: 'Cramps', value: 'mild'),
            ],
          ),
          LogEntry(
            date: DateTime(2026, 1, 3),
            isPeriodDay: false,
            symptoms: <LoggedSymptom>[
              const LoggedSymptom(name: 'Cramps'),
              const LoggedSymptom(name: 'Cramps'),
            ],
          ),
        ],
      );

      expect(
        insights.symptomFrequency.frequencies,
        <SymptomFrequency>[
          const SymptomFrequency(name: 'Cramps', days: 3),
          const SymptomFrequency(name: 'Mood', days: 1),
        ],
      );
      expect(insights.symptomFrequency.summary, contains('Cramps on 3 days'));
      expect(insights.symptomFrequency.summary, contains('Mood on 1 day'));
    });

    test('describes the spread of varied Cycle lengths in plain language', () {
      final insights = computePatternInsights(
        cycles: <CycleRecord>[
          CycleRecord(
            start: DateTime(2026, 1, 1),
            cycleLengthDays: 28,
          ),
          CycleRecord(
            start: DateTime(2026, 1, 29),
            cycleLengthDays: 32,
          ),
        ],
        periods: const <Period>[],
        logEntries: const <LogEntry>[],
      );

      expect(insights.variability.shortest, 28);
      expect(insights.variability.longest, 32);
      expect(insights.variability.spread, 4);
      expect(insights.variability.deviations, <int>[2, 2]);
      expect(insights.variability.summary, contains('from 28 to 32 days'));
      expect(insights.variability.summary, contains('spread of 4 days'));
      expect(insights.variability.summary, contains('Estimate is shown as a range'));
    });

    test('an empty history gives honest "log more" summaries', () {
      final insights = PatternInsights.empty;

      expect(
        insights.cycleLength.summary,
        'Log at least two period starts to see your average Cycle length.',
      );
      expect(
        insights.bleedDuration.summary,
        'Mark a period as ended to see your average Bleed duration.',
      );
      expect(
        insights.symptomFrequency.summary,
        'Log a symptom to see which ones come up most often.',
      );
      expect(
        insights.variability.summary,
        'Log a few Cycles to see how much your Cycle lengths vary.',
      );
    });

    test('steady Cycle lengths are described without a spread', () {
      final insights = computePatternInsights(
        cycles: <CycleRecord>[
          CycleRecord(start: DateTime(2026, 1, 1), cycleLengthDays: 28),
          CycleRecord(start: DateTime(2026, 1, 29), cycleLengthDays: 28),
        ],
        periods: const <Period>[],
        logEntries: const <LogEntry>[],
      );

      expect(insights.variability.spread, 0);
      expect(insights.variability.summary, contains('steady at 28 days'));
      expect(insights.variability.summary, contains('narrow range'));
    });
  });

  group('InsightsDocument', () {
    test('derives every insight from the stored log entries', () {
      var document = <String, Object?>{};
      void period(DateTime start, int days) {
        for (var i = 0; i < days; i++) {
          document = document.withPeriodDay(addCalendarDays(start, i));
        }
        document = document.withPeriodEnd(
          Period(start: start),
          addCalendarDays(start, days - 1),
        );
      }

      period(DateTime(2026, 1, 1), 5);
      period(DateTime(2026, 1, 29), 4);
      period(DateTime(2026, 3, 2), 6);
      for (final day in <DateTime>[
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 2),
        DateTime(2026, 1, 3),
      ]) {
        document = document.withLoggedSymptom(day, 'Cramps');
      }

      final insights = document.patternInsights;

      expect(insights.cycleLength.lengths, <int>[28, 32]);
      expect(insights.cycleLength.average, 30);
      expect(insights.bleedDuration.durations, <int>[5, 4, 6]);
      expect(insights.symptomFrequency.frequencies, <SymptomFrequency>[
        const SymptomFrequency(name: 'Cramps', days: 3),
      ]);
      expect(insights.variability.spread, 4);
    });
  });
}
