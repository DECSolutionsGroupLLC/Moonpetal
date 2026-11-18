import 'dart:math' as math;

import 'cycles.dart';
import 'estimate.dart';

/// The four estimated Phases of a Cycle, in their usual order.
enum CyclePhase { menstrual, follicular, ovulatory, luteal }

/// One estimated Phase between two calendar dates, both inclusive.
class PhaseEstimate {
  const PhaseEstimate({
    required this.phase,
    required this.start,
    required this.end,
  });

  final CyclePhase phase;
  final DateTime start;
  final DateTime end;
}

/// Typical length of the span from ovulation to the next Period, in days.
const int _assumedLutealDays = 14;

/// Fallback when no completed Cycle has a recorded Bleed duration.
const int _defaultBleedDays = 5;

/// Shortest span that still fits four distinct, non-overlapping Phases.
const int _minDisplayedCycleDays = 8;

/// Builds the four Phase estimates for the Cycle that ends at [nextPeriod].
///
/// Phases are always estimates: the Cycle length comes from the same
/// recent-leaning history as the next-period Estimate, and Bleed duration is
/// the user's typical recorded one. The ovulation-day calculation exists only
/// to place the ovulatory Phase; it is not a dated ovulation or "safe" day.
List<PhaseEstimate> estimatePhases({
  required Iterable<CycleRecord> cycles,
  required NextPeriodEstimate nextPeriod,
}) {
  final history = cycles.toList();
  final cycleLength = math.max(
    _minDisplayedCycleDays,
    weightedCycleLengthDays(history),
  );
  final recordedBleeds = history
      .map((cycle) => cycle.bleedDurationDays)
      .whereType<int>()
      .toList();
  final typicalBleed = recordedBleeds.isEmpty
      ? _defaultBleedDays
      : recordedBleeds.reduce((a, b) => a + b) ~/ recordedBleeds.length;

  final cycleStart = addCalendarDays(nextPeriod.date, -cycleLength);
  final lutealDays = math.min(
    _assumedLutealDays,
    math.max(4, math.min(cycleLength - 4, cycleLength ~/ 2)),
  );
  // Leave room for a follicular span even when the Cycle is unusually short.
  final bleedDays = math.max(
    1,
    math.min(typicalBleed, cycleLength - lutealDays - 3),
  );

  final menstrualEnd = addCalendarDays(cycleStart, bleedDays - 1);
  final ovulationDay = addCalendarDays(nextPeriod.date, -lutealDays);
  final ovulatoryStart = addCalendarDays(ovulationDay, -1);
  final ovulatoryEnd = addCalendarDays(ovulationDay, 1);

  return <PhaseEstimate>[
    PhaseEstimate(
      phase: CyclePhase.menstrual,
      start: cycleStart,
      end: menstrualEnd,
    ),
    PhaseEstimate(
      phase: CyclePhase.follicular,
      start: addCalendarDays(menstrualEnd, 1),
      end: addCalendarDays(ovulatoryStart, -1),
    ),
    PhaseEstimate(
      phase: CyclePhase.ovulatory,
      start: ovulatoryStart,
      end: ovulatoryEnd,
    ),
    PhaseEstimate(
      phase: CyclePhase.luteal,
      start: addCalendarDays(ovulatoryEnd, 1),
      end: addCalendarDays(nextPeriod.date, -1),
    ),
  ];
}
