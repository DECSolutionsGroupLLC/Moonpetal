/// The single clock seam used by date-dependent behaviour.
///
/// Tests substitute a fixed implementation so dates are deterministic.
abstract interface class Clock {
  DateTime now();
}

/// The clock used by the running app.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
