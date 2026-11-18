import 'package:flutter/material.dart';

import 'src/clock.dart';
import 'src/home_view.dart';
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
  late final Future<Map<String, Object?>> _document = widget.store.read();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moonpetal',
      debugShowCheckedModeBanner: false,
      theme: moonpetalTheme,
      home: PhoneViewport(
        child: FutureBuilder<Map<String, Object?>>(
          future: _document,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return HomeView(
              today: widget.clock.now(),
              hasLogEntries: snapshot.data!.hasLogEntries,
            );
          },
        ),
      ),
    );
  }
}
