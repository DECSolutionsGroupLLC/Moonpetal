import 'periods.dart';

/// One completed cycle in the history.
///
/// A cycle runs from one period's start to the next period's start. [start] is
/// the start of the period that began this cycle; [cycleLengthDays] is the
/// start-to-start span to the following period; [bleedDurationDays] is the
/// bleed that began the cycle, or null if that period was left open.
class CycleRecord {
  const CycleRecord({
    required this.start,
    required this.cycleLengthDays,
    this.bleedDurationDays,
  });

  final DateTime start;
  final int cycleLengthDays;
  final int? bleedDurationDays;
}

/// Days between two calendar dates, counted in UTC so daylight-saving changes
/// cannot shift a count by a day.
int _daysBetween(DateTime start, DateTime end) => DateTime.utc(
      end.year,
      end.month,
      end.day,
    ).difference(
          DateTime.utc(start.year, start.month, start.day),
        ).inDays;

/// Builds the history of completed cycles, oldest first.
///
/// The most recent period has no following start yet, so it has no completed
/// cycle and is omitted. Cycle length is the day count from one period start
/// to the next; bleed duration is taken from the period that began the cycle.
List<CycleRecord> computeCycleHistory(Iterable<Period> periods) {
  final ordered = periods.toList()..sort((a, b) => a.start.compareTo(b.start));

  return <CycleRecord>[
    for (var i = 0; i + 1 < ordered.length; i++)
      CycleRecord(
        start: ordered[i].start,
        cycleLengthDays: _daysBetween(ordered[i].start, ordered[i + 1].start),
        bleedDurationDays: ordered[i].bleedDurationDays,
      ),
  ];
}

/// Typed cycle reads on the stored document.
extension CycleDocument on Map<String, Object?> {
  /// The history of completed cycles, oldest first, derived from the periods.
  List<CycleRecord> get cycleHistory => computeCycleHistory(periods);
}
