import 'dart:math' as math;

import 'cycles.dart';

/// Completed cycles needed before a next-period Estimate is worth showing.
const int minCyclesForEstimate = 2;

/// A next-period Estimate: a central date with a visible range around it.
///
/// The range, not the central date, is what the user should read. All wording
/// built from this lives in [explanation] so the UI cannot present a computed
/// date as a promise.
class NextPeriodEstimate {
  const NextPeriodEstimate({
    required this.date,
    required this.rangeStart,
    required this.rangeEnd,
    required this.windowDays,
    required this.explanation,
  });

  /// The middle of the estimated window, for orienting the user.
  final DateTime date;

  /// The earliest day in the visible range.
  final DateTime rangeStart;

  /// The latest day in the visible range.
  final DateTime rangeEnd;

  /// How many days the visible range covers, for the plain-language copy.
  final int windowDays;

  /// Plain-language derivation of the Estimate, without promising a date.
  final String explanation;
}

/// Days added on a calendar-date basis so daylight-saving changes cannot
/// shift the displayed day.
DateTime addCalendarDays(DateTime date, int days) {
  final shifted = DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).add(Duration(days: days));
  return DateTime(shifted.year, shifted.month, shifted.day);
}

/// Sum of [values] paired with [weights].
double _weightedSum(List<int> values, List<double> weights) {
  var total = 0.0;
  for (var i = 0; i < values.length; i++) {
    total += weights[i] * values[i];
  }
  return total;
}

/// The recent-leaning Cycle length, in days, shared by the next-period and
/// phase estimates so the two agree on how long a Cycle is.
int weightedCycleLengthFromDays(List<int> lengths) {
  if (lengths.isEmpty) return 0;
  final weights = <double>[
    for (var i = 0; i < lengths.length; i++)
      math.pow(2, i - (lengths.length - 1)).toDouble(),
  ];
  final totalWeight = weights.fold<double>(0, (sum, weight) => sum + weight);
  return (_weightedSum(lengths, weights) / totalWeight).round();
}

/// The recent-leaning Cycle length, in days, from a Cycle history.
int weightedCycleLengthDays(Iterable<CycleRecord> cycles) => weightedCycleLengthFromDays(
  cycles.map((cycle) => cycle.cycleLengthDays).toList(),
);

/// Builds a next-period Estimate from [cycles], or null when there are too few
/// completed cycles to say anything honest. [today] keeps the result ahead of
/// the user when no period has been logged for a long time.
NextPeriodEstimate? estimateNextPeriod(
  Iterable<CycleRecord> cycles, {
  required DateTime today,
}) {
  final history = cycles.toList();
  if (history.length < minCyclesForEstimate) return null;

  final lengths = history.map((cycle) => cycle.cycleLengthDays).toList();
  final cycleStep = weightedCycleLengthFromDays(lengths);

  // Variability is observed across every logged cycle; recency decides where
  // the centre sits, not how honest the width is about scattered data.
  final plainMean = lengths.reduce((a, b) => a + b) / lengths.length;
  final variance = lengths
          .map((length) {
            final difference = length - plainMean;
            return difference * difference;
          })
          .reduce((a, b) => a + b) /
      lengths.length;
  final deviation = math.sqrt(variance);

  // A narrow floor keeps a steady pattern honest, while variability widens
  // the window so a scattered history is not shown as one confident day.
  final halfWindow = math.max(1, (deviation * 1.5).round());
  final lengthsVaried = halfWindow > 1;

  // The latest period's start is the anchor; the latest completed cycle gives
  // the span from the previous start to it.
  final latestPeriodStart = addCalendarDays(
    history.last.start,
    history.last.cycleLengthDays,
  );
  var centre = addCalendarDays(latestPeriodStart, cycleStep);
  while (cycleStep > 0 && !centre.isAfter(today)) {
    centre = addCalendarDays(centre, cycleStep);
  }
  final rangeStart = addCalendarDays(centre, -halfWindow);
  final rangeEnd = addCalendarDays(centre, halfWindow);

  final variabilityCopy = lengthsVaried
      ? 'Your cycle lengths varied, so the range is wider.'
      : 'Your cycle lengths were fairly regular, so the range is narrow.';

  return NextPeriodEstimate(
    date: centre,
    rangeStart: rangeStart,
    rangeEnd: rangeEnd,
    windowDays: 2 * halfWindow + 1,
    explanation: 'Based on your ${history.length} most recent cycles, with the '
        'latest counting more. $variabilityCopy This is an estimate, not an '
        'exact date or medical advice.',
  );
}
