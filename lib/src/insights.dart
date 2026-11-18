import 'dart:math' as math;

import 'cycles.dart';
import 'log_entries.dart';
import 'periods.dart';

/// A note shown with the insights so they are never mistaken for advice.
///
/// Insights describe only what the user logged; they make no medical claim.
const String insightsNotMedicalAdvice =
    'These insights summarise only what you logged. They are not medical '
    'advice or a diagnosis.';

String _days(int count) => count == 1 ? 'day' : 'days';

/// How often one named symptom was logged, counted in distinct days.
class SymptomFrequency {
  const SymptomFrequency({required this.name, required this.days});

  final String name;

  /// Number of separate days the symptom appears on.
  final int days;

  @override
  bool operator ==(Object other) =>
      other is SymptomFrequency && other.name == name && other.days == days;

  @override
  int get hashCode => Object.hash(name, days);
}

/// The average start-to-start Cycle length across completed Cycles.
class CycleLengthInsight {
  const CycleLengthInsight({required this.lengths, required this.average});

  /// Individual Cycle lengths in days, oldest first.
  final List<int> lengths;

  /// Mean length in days, or null when no Cycle has completed.
  final double? average;

  /// Same insight as the chart, in plain language.
  String get summary {
    final mean = average;
    if (mean == null) {
      return 'Log at least two period starts to see your average Cycle length.';
    }
    return 'Your Cycle length averaged about ${mean.toStringAsFixed(0)} '
        '${_days(mean.round())} across the ${lengths.length} '
        '${lengths.length == 1 ? 'cycle' : 'cycles'} you logged.';
  }
}

/// The average Bleed duration across Periods the user explicitly ended.
class BleedDurationInsight {
  const BleedDurationInsight({required this.durations, required this.average});

  /// Recorded Bleed durations in days, oldest first.
  final List<int> durations;

  /// Mean duration in days, or null when no Period has an end.
  final double? average;

  /// Same insight as the chart, in plain language.
  String get summary {
    final mean = average;
    if (mean == null) {
      return 'Mark a period as ended to see your average Bleed duration.';
    }
    return 'Your periods lasted about ${mean.toStringAsFixed(0)} '
        '${_days(mean.round())} on average across the ${durations.length} '
        '${durations.length == 1 ? 'period' : 'periods'} you ended.';
  }
}

/// How often each symptom appears across the user's logged days.
class SymptomFrequencyInsight {
  const SymptomFrequencyInsight({required this.frequencies});

  /// Most frequent symptom first, ties broken by name.
  final List<SymptomFrequency> frequencies;

  /// Same insight as the chart, in plain language.
  String get summary {
    if (frequencies.isEmpty) {
      return 'Log a symptom to see which ones come up most often.';
    }
    final top = frequencies.first;
    final buffer = StringBuffer(
      'You logged ${top.name} on ${top.days} ${_days(top.days)}',
    );
    if (frequencies.length == 1) {
      buffer.write('.');
    } else if (frequencies.length == 2) {
      final next = frequencies[1];
      buffer.write(', and ${next.name} on ${next.days} ${_days(next.days)}.');
    } else {
      buffer.write(', more than any other symptom. You also logged ');
      buffer.write(
        frequencies
            .skip(1)
            .map((item) => '${item.name} on ${item.days} ${_days(item.days)}')
            .join(', '),
      );
      buffer.write('.');
    }
    return buffer.toString();
  }
}

/// How much the logged Cycle lengths varied.
class VariabilityInsight {
  const VariabilityInsight({
    required this.lengths,
    required this.deviations,
    required this.shortest,
    required this.longest,
    required this.spread,
  });

  /// Individual Cycle lengths in days, oldest first.
  final List<int> lengths;

  /// Each length's distance from the average, for the variability chart.
  final List<int> deviations;

  final int? shortest;
  final int? longest;

  /// Longest length minus shortest, or null with too few Cycles.
  final int? spread;

  /// Same insight as the chart, in plain language.
  String get summary {
    final short = shortest;
    final long = longest;
    final gap = spread;
    if (short == null || long == null || gap == null || lengths.length < 2) {
      return 'Log a few Cycles to see how much your Cycle lengths vary.';
    }
    if (gap == 0) {
      return 'Your Cycle lengths were steady at $short '
          '${_days(short)}, so your next-period Estimate is a narrow range.';
    }
    return 'Your Cycle lengths ranged from $short to $long days, a spread of '
        '$gap ${_days(gap)}. That is why your next-period Estimate is shown as '
        'a range rather than one day.';
  }
}

/// All four pattern insights, derived only from what the user logged.
class PatternInsights {
  const PatternInsights({
    required this.cycleLength,
    required this.bleedDuration,
    required this.symptomFrequency,
    required this.variability,
  });

  /// Honest empty state: every summary asks for more data.
  static const PatternInsights empty = PatternInsights(
    cycleLength: CycleLengthInsight(lengths: <int>[], average: null),
    bleedDuration: BleedDurationInsight(durations: <int>[], average: null),
    symptomFrequency: SymptomFrequencyInsight(frequencies: <SymptomFrequency>[]),
    variability: VariabilityInsight(
      lengths: <int>[],
      deviations: <int>[],
      shortest: null,
      longest: null,
      spread: null,
    ),
  );

  final CycleLengthInsight cycleLength;
  final BleedDurationInsight bleedDuration;
  final SymptomFrequencyInsight symptomFrequency;
  final VariabilityInsight variability;
}

/// Builds the pattern insights from completed Cycles and logged days.
PatternInsights computePatternInsights({
  required Iterable<CycleRecord> cycles,
  required Iterable<Period> periods,
  required Iterable<LogEntry> logEntries,
}) {
  final history = cycles.toList();
  final lengths = history.map((cycle) => cycle.cycleLengthDays).toList();

  // Bleed duration belongs to a Period, including the most recent one that has
  // no following start and so is not yet a completed Cycle.
  final bleeds = periods
      .map((period) => period.bleedDurationDays)
      .whereType<int>()
      .toList();

  // Count distinct days per symptom: a day that lists a name twice is still
  // one day of that symptom.
  final daysByName = <String, Set<String>>{};
  for (final entry in logEntries) {
    for (final symptom in entry.symptoms) {
      daysByName.putIfAbsent(symptom.name, () => <String>{}).add(entry.dayKey);
    }
  }
  final frequencies = daysByName.entries
      .map(
        (item) => SymptomFrequency(name: item.key, days: item.value.length),
      )
      .toList()
    ..sort((a, b) {
      final byCount = b.days.compareTo(a.days);
      return byCount != 0 ? byCount : a.name.compareTo(b.name);
    });

  final averageLength = lengths.isEmpty
      ? null
      : lengths.reduce((a, b) => a + b) / lengths.length;
  final shortest = lengths.isEmpty ? null : lengths.reduce(math.min);
  final longest = lengths.isEmpty ? null : lengths.reduce(math.max);

  return PatternInsights(
    cycleLength: CycleLengthInsight(
      lengths: lengths,
      average: averageLength,
    ),
    bleedDuration: BleedDurationInsight(
      durations: bleeds,
      average: bleeds.isEmpty
          ? null
          : bleeds.reduce((a, b) => a + b) / bleeds.length,
    ),
    symptomFrequency: SymptomFrequencyInsight(frequencies: frequencies),
    variability: VariabilityInsight(
      lengths: lengths,
      deviations: averageLength == null
          ? <int>[]
          : lengths.map((length) => (length - averageLength).abs().round()).toList(),
      shortest: shortest,
      longest: longest,
      spread: shortest == null || longest == null ? null : longest - shortest,
    ),
  );
}

/// Typed insight reads on the stored document.
extension InsightsDocument on Map<String, Object?> {
  /// Pattern insights recomputed from the current periods and log entries.
  PatternInsights get patternInsights => computePatternInsights(
        cycles: cycleHistory,
        periods: periods,
        logEntries: logEntries,
      );
}
