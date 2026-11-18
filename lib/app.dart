import 'package:flutter/material.dart';

import 'src/clock.dart';
import 'src/home_view.dart';
import 'src/log_entries.dart';
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

  Future<void> _logPeriodDay() async {
    final updated = (_document ?? <String, Object?>{}).withPeriodDay(
      widget.clock.now(),
    );
    await widget.store.write(updated);
    if (!mounted) return;
    setState(() => _document = updated);
  }

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
                onLogPeriodDay: _logPeriodDay,
              ),
      ),
    );
  }
}
