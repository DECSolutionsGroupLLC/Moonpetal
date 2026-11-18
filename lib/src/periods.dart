import 'package:intl/intl.dart';

import 'log_entries.dart';

/// The key under which explicitly recorded period ends live in the document.
const String periodEndsKey = 'periodEnds';

final DateFormat _dayFormat = DateFormat('yyyy-MM-dd');

/// Drops the time of day so date arithmetic works on calendar days only.
DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// The number of calendar days from [start] to [end], including both days.
///
/// Using UTC keeps the count stable across daylight-saving transitions.
int _calendarDaysBetween(DateTime start, DateTime end) =>
    DateTime.utc(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime.utc(start.year, start.month, start.day)).inDays +
    1;

/// One bleed episode.
///
/// [end] is null while the period is open. An end is never inferred from
/// logged days — the user records it explicitly.
class Period {
  const Period({required this.start, this.end});

  final DateTime start;
  final DateTime? end;

  bool get isOpen => end == null;

  String get startKey => _dayFormat.format(start);

  /// Calendar days between the start and end, including both days.
  ///
  /// Null while the period is open: there is no guessed bleed duration.
  int? get bleedDurationDays {
    final end = this.end;
    if (end == null) return null;
    return _calendarDaysBetween(start, end);
  }

  @override
  String toString() =>
      'Period($startKey${end == null ? '' : '→${_dayFormat.format(end!)}'})';
}

/// Groups logged period days into bleed episodes.
///
/// Days on consecutive calendar dates form one [Period]. A gap starts a new
/// period; it never produces a guessed end for the earlier one. An end that
/// the user explicitly recorded for a period's start date is applied to it.
List<Period> groupPeriodDays(
  Iterable<DateTime> days, {
  Map<String, DateTime>? ends,
}) {
  final uniqueDays = <String, DateTime>{};
  for (final day in days) {
    uniqueDays.putIfAbsent(_dayFormat.format(day), () => _dateOnly(day));
  }
  if (uniqueDays.isEmpty) return <Period>[];

  final sorted = uniqueDays.values.toList()..sort();
  final runs = <List<DateTime>>[
    <DateTime>[sorted.first],
  ];
  for (final day in sorted.skip(1)) {
    final last = runs.last.last;
    final nextDay = DateTime(last.year, last.month, last.day + 1);
    if (day == nextDay) {
      runs.last.add(day);
    } else {
      runs.add(<DateTime>[day]);
    }
  }

  return <Period>[
    for (final run in runs)
      Period(
        start: run.first,
        end: ends == null ? null : ends[_dayFormat.format(run.first)],
      ),
  ];
}

/// Typed period reads and writes on the stored document.
extension PeriodDocument on Map<String, Object?> {
  /// Explicit ends, keyed by the start date of the period they belong to.
  Map<String, DateTime> get periodEnds {
    final stored = this[periodEndsKey];
    if (stored is! Map) return <String, DateTime>{};

    return <String, DateTime>{
      for (final entry in stored.entries)
        entry.key as String: _dateOnly(
          entry.value is DateTime
              ? entry.value as DateTime
              : DateTime.parse(entry.value as String),
        ),
    };
  }

  /// The user's periods, oldest first, derived from the logged period days.
  List<Period> get periods =>
      groupPeriodDays(periodDays.map((entry) => entry.date), ends: periodEnds);

  /// Returns a new document with [period] ended on [end].
  Map<String, Object?> withPeriodEnd(Period period, DateTime end) {
    final endDate = _dateOnly(end);
    if (endDate.isBefore(period.start)) {
      throw ArgumentError.value(
        endDate,
        'end',
        'A period cannot end before it starts.',
      );
    }

    final ends = <String, Object?>{
      for (final entry in periodEnds.entries)
        entry.key: _dayFormat.format(entry.value),
    };
    ends[period.startKey] = _dayFormat.format(endDate);
    return <String, Object?>{...this, periodEndsKey: ends};
  }
}
