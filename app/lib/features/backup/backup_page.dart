import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import '../../core/ffi_bridge.dart';
import '../../core/call_service.dart';
import '../../main.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> with TickerProviderStateMixin {
  String _backupDir = '';
  Map<String, dynamic> _backupStatus = {};
  int _backupIntervalMinutes = 5;
  bool _isBackingUp = false;
  Timer? _refreshTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _loadBackupInfo();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadBackupInfo());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _loadBackupInfo() {
    setState(() {
      _backupDir = FFIBridge.getBackupDir();
      _backupStatus = FFIBridge.getBackupStatus();
    });
  }

  Future<void> _triggerManualBackup() async {
    setState(() => _isBackingUp = true);
    await Future.delayed(const Duration(milliseconds: 300));
    final result = FFIBridge.triggerBackup();
    _loadBackupInfo();
    setState(() => _isBackingUp = false);

    if (mounted) {
      final isError = result.startsWith('error:');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isError ? result : '✓ Backup complete'),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green,
      ));
    }
  }

  Future<void> _changeBackupDir() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose Backup Folder',
    );
    if (result != null) {
      FFIBridge.setBackupDir(result);
      _loadBackupInfo();
    }
  }

  Future<void> _restoreFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      dialogTitle: 'Select contacts_backup.json',
    );
    if (result != null && mounted) {
      final path = result.files.single.path!;
      final status = FFIBridge.restoreFromBackup(path);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status)));
    }
  }

  Future<void> _requestBatteryOptimization() async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (!status.isGranted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.battery_alert_rounded, color: Colors.orange, size: 32),
          title: const Text('Battery Exemption'),
          content: const Text(
            'To enable reliable background backups, allow the app to run unrestricted in the background.\n\nPlease press "Allow" on the system prompt.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await Permission.ignoreBatteryOptimizations.request();
              },
              child: const Text('Grant Access'),
            ),
          ],
        ),
      );
    }
  }

  String _formatTimestamp(int timestamp) {
    if (timestamp == 0) return 'Never';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final lastBackup = _backupStatus['last_backup_time'] ?? 0;
    final contactCount = _backupStatus['contact_count'] ?? 0;
    final backupPath = _backupStatus['backup_path'] ?? '';

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Backup & Settings'),
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ─── Settings Section ───────────────────────────────────────
            Card(
              elevation: 0,
              color: colors.surfaceContainerHighest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.settings_suggest_rounded, size: 18, color: colors.primary),
                        const SizedBox(width: 8),
                        Text('APP SETTINGS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: colors.primary)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Theme Toggle
                    Row(
                      children: [
                        const Expanded(child: Text('Theme Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                        SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded, size: 18)),
                            ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded, size: 18)),
                            ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded, size: 18)),
                          ],
                          selected: {themeNotifier.value},
                          onSelectionChanged: (Set<ThemeMode> newSelection) {
                            setState(() { themeNotifier.value = newSelection.first; });
                          },
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),

                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ─── Hero Card ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primaryContainer, colors.surfaceContainerHighest],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.backup_rounded, size: 36, color: colors.onPrimaryContainer),
                  const SizedBox(height: 12),
                  Text('Zero-Effort Backup',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.onPrimaryContainer)),
                  const SizedBox(height: 6),
                  Text(
                    'Contacts are automatically saved to a local folder. Use Syncthing, Dropbox, OneDrive, or any folder-sync app to keep them in the cloud.',
                    style: TextStyle(fontSize: 13, color: colors.onPrimaryContainer.withValues(alpha: 0.8), height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── Backup Status ──────────────────────────────────────────
            Card(
              elevation: 0,
              color: colors.surfaceContainerHighest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18, color: colors.primary),
                        const SizedBox(width: 8),
                        Text('BACKUP STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: colors.primary)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _StatusRow(label: 'Last Backup', value: _formatTimestamp(lastBackup), icon: Icons.schedule_rounded),
                    const SizedBox(height: 10),
                    _StatusRow(label: 'Contacts', value: '$contactCount', icon: Icons.people_rounded),
                    const SizedBox(height: 10),
                    _StatusRow(
                      label: 'Backup Folder',
                      value: _backupDir.isNotEmpty ? _backupDir : 'Not set',
                      icon: Icons.folder_rounded,
                      maxLines: 2,
                    ),
                    if (backupPath.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _StatusRow(label: 'File', value: 'contacts_backup.json', icon: Icons.description_rounded),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ─── Daemon toggle ──────────────────────────────────────────
            Card(
              elevation: 0,
              color: colors.surfaceContainerHighest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: FutureBuilder<bool>(
                future: FlutterBackgroundService().isRunning(),
                builder: (context, snapshot) {
                  final isRunning = snapshot.data ?? false;
                  return SwitchListTile(
                    title: const Text('Auto Backup', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(isRunning ? 'Active · Every $_backupIntervalMinutes min' : 'Disabled', style: const TextStyle(fontSize: 12)),
                    secondary: Icon(
                      isRunning ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      color: isRunning ? Colors.green : colors.onSurfaceVariant,
                    ),
                    value: isRunning,
                    onChanged: (val) async {
                      if (val) await _requestBatteryOptimization();
                      final service = FlutterBackgroundService();
                      if (val) { await service.startService(); } else { service.invoke("stopService"); }
                      setState(() {});
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // ─── Backup Interval ────────────────────────────────────────
            Card(
              elevation: 0,
              color: colors.surfaceContainerHighest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.timer_rounded, size: 20, color: colors.primary),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Backup Interval', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 1, label: Text('1m', style: TextStyle(fontSize: 11))),
                        ButtonSegment(value: 5, label: Text('5m', style: TextStyle(fontSize: 11))),
                        ButtonSegment(value: 10, label: Text('10m', style: TextStyle(fontSize: 11))),
                      ],
                      selected: {_backupIntervalMinutes},
                      onSelectionChanged: (Set<int> v) {
                        setState(() => _backupIntervalMinutes = v.first);
                        FlutterBackgroundService().invoke('setInterval', {'minutes': v.first});
                      },
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text('ACTIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: colors.primary)),
            const SizedBox(height: 12),

            _ActionCard(
              title: 'Backup Now',
              subtitle: 'Manually trigger a backup',
              icon: Icons.backup_rounded,
              color: colors.primary,
              isLoading: _isBackingUp,
              onTap: _triggerManualBackup,
            ),
            const SizedBox(height: 8),
            _ActionCard(
              title: 'Change Backup Folder',
              subtitle: _backupDir.isNotEmpty ? _backupDir.split('/').last : 'Choose a directory',
              icon: Icons.folder_open_rounded,
              color: colors.tertiary,
              onTap: _changeBackupDir,
            ),
            const SizedBox(height: 8),
            _ActionCard(
              title: 'Restore from Backup',
              subtitle: 'Import contacts from a backup file',
              icon: Icons.settings_backup_restore_rounded,
              color: colors.secondary,
              onTap: _restoreFromFile,
            ),
            const SizedBox(height: 24),

            // ─── Info Box ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_rounded, size: 16, color: Colors.amber.shade600),
                      const SizedBox(width: 8),
                      Text('HOW IT WORKS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: colors.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '1. Set the backup folder to your Syncthing, Dropbox, or OneDrive sync directory\n'
                    '2. Contacts are saved as contacts_backup.json automatically\n'
                    '3. Your sync app handles the cloud upload — zero configuration needed\n'
                    '4. To restore on another device, just pick the backup file',
                    style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─── Status Row ──────────────────────────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final int maxLines;

  const _StatusRow({required this.label, required this.value, required this.icon, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(label, style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: maxLines, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

// ─── Action Card ─────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isLoading;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0, margin: EdgeInsets.zero, color: colors.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        splashColor: color.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: isLoading
                    ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: color))
                    : Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
