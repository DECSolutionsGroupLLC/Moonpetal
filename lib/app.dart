import 'package:flutter/material.dart';

import 'src/clock.dart';
import 'src/cycles.dart';
import 'src/home_view.dart';
import 'src/log_entries.dart';
import 'src/periods.dart';
import 'src/phone_viewport.dart';
import 'src/storage.dart';
import 'src/theme.dart';

/// Root widget. Clock and store are injected so tests can substitute both.
class MoonpetalApp extends StatefulWidget {
  const MoonpetalApp({super.key, Clock? clock, AppStore? store})
    : clock = clock ?? const SystemClock(),
      store = store ?? const JsonFileAppStore();

  final Clock clock;
  final AppStore store;

  @override
  State<MoonpetalApp> createState() => _MoonpetalAppState();
}

class _MoonpetalAppState extends State<MoonpetalApp> {
  Map<String, Object?>? _document;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final document = await widget.store.read();
    if (!mounted) return;
    setState(() => _document = document);
  }

  /// Applies a document transform, persists it, then shows the new state.
  Future<void> _commit(
    Map<String, Object?> Function(Map<String, Object?> document) update,
  ) async {
    final updated = update(_document ?? <String, Object?>{});
    await widget.store.write(updated);
    if (!mounted) return;
    setState(() => _document = updated);
  }

  Future<void> _recordPeriodDay(DateTime day) =>
      _commit((document) => document.withPeriodDay(day));

  Future<void> _logPeriodDay() => _recordPeriodDay(widget.clock.now());

  Future<void> _recordFlowLevel(DateTime day, FlowLevel? level) =>
      _commit((document) => document.withFlowLevel(day, level));

  Future<void> _setFlowLevel(FlowLevel? level) =>
      _recordFlowLevel(widget.clock.now(), level);

  Future<void> _endPeriod(Period period, DateTime end) =>
      _commit((document) => document.withPeriodEnd(period, end));

  @override
  Widget build(BuildContext context) {
    final document = _document;

    return MaterialApp(
      title: 'Moonpetal',
      debugShowCheckedModeBanner: false,
      theme: moonpetalTheme,
      home: PhoneViewport(
        child: document == null
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : HomeView(
                today: widget.clock.now(),
                hasLogEntries: document.hasLogEntries,
                periodDays: document.periodDays,
                flowDays: document.flowDays,
                periods: document.periods,
                cycleHistory: document.cycleHistory,
                todayFlowLevel: document.flowLevelFor(widget.clock.now()),
                onLogPeriodDay: _logPeriodDay,
                onSetPeriodStart: _recordPeriodDay,
                onSetFlowLevel: _setFlowLevel,
                onEndPeriod: _endPeriod,
              ),
      ),
    );
  }
}
