import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'theme.dart';

/// The single screen for this slice; later tickets add logging above it.
class HomeView extends StatelessWidget {
  const HomeView({super.key, required this.today, required this.hasLogEntries});

  final DateTime today;
  final bool hasLogEntries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: hasLogEntries
                  ? Text(
                      'Your entries are stored on this device.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    )
                  : _FirstRunEmptyState(today: today),
            ),
          ),
        ),
      ),
    );
  }
}

class _FirstRunEmptyState extends StatelessWidget {
  const _FirstRunEmptyState({required this.today});

  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: MoonpetalColors.softPink,
          child: const Icon(
            Icons.local_florist,
            size: 40,
            color: MoonpetalColors.deepPink,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Welcome to Moonpetal',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: MoonpetalColors.deepPink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Nothing logged yet. Start by marking today as a period day, or by '
          'logging how you feel.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        Text(
          'Today, ${DateFormat('EEEE d MMMM y').format(today)}',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
