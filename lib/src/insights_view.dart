import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'insights.dart';
import 'theme.dart';

/// A separate screen summarising the user's patterns in charts and words.
///
/// Every chart sits directly above the plain-language sentence that says the
/// same thing, so the insight never depends on reading the graphic. No value
/// here is framed as medical advice.
class InsightsView extends StatelessWidget {
  const InsightsView({super.key, required this.insights});

  final PatternInsights insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your patterns',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: MoonpetalColors.deepPink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'A plain-language look at what you logged on this device.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _InsightCard(
                cardKey: const Key('insight-cycleLength'),
                title: 'Cycle length',
                chart: _InsightBarChart(values: insights.cycleLength.lengths),
                summary: insights.cycleLength.summary,
                summaryKey: const Key('insight-cycleLength-summary'),
              ),
              _InsightCard(
                cardKey: const Key('insight-bleedDuration'),
                title: 'Bleed duration',
                chart: _InsightBarChart(values: insights.bleedDuration.durations),
                summary: insights.bleedDuration.summary,
                summaryKey: const Key('insight-bleedDuration-summary'),
              ),
              _InsightCard(
                cardKey: const Key('insight-symptoms'),
                title: 'Symptom frequency',
                chart: _InsightBarChart(
                  values: insights.symptomFrequency.frequencies
                      .map((item) => item.days)
                      .toList(),
                  labels: insights.symptomFrequency.frequencies
                      .map((item) => item.name)
                      .toList(),
                  labelWidth: 96,
                  unit: 'days logged',
                ),
                summary: insights.symptomFrequency.summary,
                summaryKey: const Key('insight-symptoms-summary'),
              ),
              _InsightCard(
                cardKey: const Key('insight-variability'),
                title: 'Cycle length variability',
                chart: _InsightBarChart(
                  values: insights.variability.deviations,
                  unit: 'days from average',
                ),
                summary: insights.variability.summary,
                summaryKey: const Key('insight-variability-summary'),
              ),
              const SizedBox(height: 16),
              Container(
                key: const Key('insightsNotMedicalAdvice'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MoonpetalColors.softPink,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  insightsNotMedicalAdvice,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: MoonpetalColors.deepPink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One readable chart with its plain-language sentence immediately after it.
class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.cardKey,
    required this.title,
    required this.chart,
    required this.summary,
    required this.summaryKey,
  });

  final Key cardKey;
  final String title;
  final Widget chart;
  final String summary;
  final Key summaryKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: cardKey,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: MoonpetalColors.deepPink,
              ),
            ),
            const SizedBox(height: 12),
            chart,
            const SizedBox(height: 12),
            Text(
              summary,
              key: summaryKey,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: MoonpetalColors.deepPink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small bar chart built from plain widgets so it stays readable and needs
/// no chart package. Bars are tinted deep pink on a soft-pink track, and each
/// bar carries a semantics label for screen readers.
class _InsightBarChart extends StatelessWidget {
  const _InsightBarChart({
    required this.values,
    this.labels = const <String>[],
    this.labelWidth = 44,
    this.unit = 'days',
  });

  final List<int> values;
  final List<String> labels;
  final double labelWidth;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (values.isEmpty) {
      return Text(
        'Nothing logged to chart yet.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final peak = values.reduce(math.max);
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: MoonpetalColors.deepPink,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < values.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Semantics(
              label: '${_labelAt(i)}: ${values[i]} $unit',
              child: Row(
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: Text(
                      _labelAt(i),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 18,
                      decoration: BoxDecoration(
                        color: MoonpetalColors.softPink,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: peak == 0 ? 0.0 : values[i] / peak,
                        child: Container(
                          decoration: BoxDecoration(
                            color: MoonpetalColors.deepPink,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${values[i]}',
                      textAlign: TextAlign.end,
                      style: labelStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _labelAt(int index) =>
      index < labels.length ? labels[index] : '${index + 1}';
}
