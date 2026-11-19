import 'package:flutter/material.dart';

import 'theme.dart';

/// Export and restore are explicit user actions in a local-only app. The
/// callbacks return a status line to show, or null when the user cancels a
/// native dialog; they report errors as status lines too, so a failed restore
/// can never leave a stale success message on screen.
class BackupView extends StatefulWidget {
  const BackupView({
    super.key,
    required this.onExport,
    required this.onRestore,
  });

  /// Writes a backup to a user-chosen location, returning a status line.
  final Future<String?> Function() onExport;

  /// Restores from a user-chosen file, returning a status line.
  final Future<String?> Function() onRestore;

  @override
  State<BackupView> createState() => _BackupViewState();
}

class _BackupViewState extends State<BackupView> {
  String? _status;
  bool _busy = false;

  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _busy = true);
    final message = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (message != null) _status = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Export & restore')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your backup',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: MoonpetalColors.deepPink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your data stays on this device. Export writes one '
                'human-readable JSON text file with every log entry, its edit '
                'history, and all your Settings — including fertility and '
                'reminders. You choose where it is saved; Moonpetal never '
                'uploads or shares it.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('backupExportButton'),
                onPressed: _busy ? null : () => _run(widget.onExport),
                icon: const Icon(Icons.save_alt),
                label: const Text('Export data'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('backupRestoreButton'),
                onPressed: _busy ? null : () => _run(widget.onRestore),
                icon: const Icon(Icons.restore),
                label: const Text('Restore from file'),
              ),
              const SizedBox(height: 8),
              Text(
                'Restoring replaces the data on this device. If the file is '
                'not a valid Moonpetal backup, nothing is changed.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (_status != null) ...[
                const SizedBox(height: 16),
                Container(
                  key: const Key('backupStatus'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MoonpetalColors.softPink,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _status!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: MoonpetalColors.deepPink,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'No account. No server. No network calls.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
