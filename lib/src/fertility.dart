import 'estimate.dart';
import 'phases.dart';
import 'storage.dart';

/// The estimated ovulation day and the estimated fertile window around it.
///
/// Both are estimates derived from the same recent-leaning cycle history as
/// the next-period and Phase estimates; neither is a guarantee or a "safe day"
/// determination.
class FertilityEstimate {
  const FertilityEstimate({
    required this.ovulationDay,
    required this.fertileStart,
    required this.fertileEnd,
  });

  /// The estimated day of ovulation, presented as an estimate.
  final DateTime ovulationDay;

  /// The earliest day of the estimated fertile window, inclusive.
  final DateTime fertileStart;

  /// The latest day of the estimated fertile window, inclusive.
  final DateTime fertileEnd;
}

/// Days before ovulation included in the estimated fertile window.
const int fertileDaysBeforeOvulation = 5;

/// Days after ovulation included in the estimated fertile window.
const int fertileDaysAfterOvulation = 1;

/// Typed access to the fertility opt-in, stored with the other Settings.
extension FertilityDocument on Map<String, Object?> {
  /// Fertility views are off unless the user has explicitly opted in.
  bool get fertilityViewEnabled => this[fertilityViewEnabledKey] == true;

  /// A copy of this document with the fertility view turned on or off.
  Map<String, Object?> withFertilityViewEnabled(bool enabled) =>
      <String, Object?>{...this, fertilityViewEnabledKey: enabled};
}

/// Builds the fertility estimate from the estimated Phases, or null when too
/// little history exists to show any estimate.
///
/// The fertility view deliberately follows the ovulatory Phase from the cycle
/// calendar: that Phase straddles the estimated ovulation day, so using its
/// first day keeps the two views consistent when cycle history changes. The
/// fertile window is a plain span around that day, never a per-day safety
/// colouring.
FertilityEstimate? estimateFertility(Iterable<PhaseEstimate> phases) {
  final ovulatory = phases
      .where((phase) => phase.phase == CyclePhase.ovulatory)
      .toList();
  if (ovulatory.isEmpty) return null;

  final ovulationDay = addCalendarDays(ovulatory.first.start, 1);
  return FertilityEstimate(
    ovulationDay: ovulationDay,
    fertileStart: addCalendarDays(ovulationDay, -fertileDaysBeforeOvulation),
    fertileEnd: addCalendarDays(ovulationDay, fertileDaysAfterOvulation),
  );
}
