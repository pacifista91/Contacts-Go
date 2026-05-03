import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'ffi_bridge.dart';

Future<void> initializeBackupDaemon() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'backup_daemon', // id
    'Backup Daemon', // name
    description: 'Runs periodic contact backups in the background.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // controlled by UI toggle
      isForegroundMode: true,
      notificationChannelId: 'backup_daemon',
      initialNotificationTitle: 'Contacts Backup',
      initialNotificationContent: 'Initializing...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();
  
  await FFIBridge.load();

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Update backup interval from service data
  int backupIntervalMinutes = 5; // default

  service.on('setInterval').listen((event) {
    if (event != null && event['minutes'] != null) {
      backupIntervalMinutes = event['minutes'] as int;
    }
  });

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Periodic backup loop
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        try {
          // Check if enough time has passed since last backup
          final status = FFIBridge.getBackupStatus();
          final lastBackupTime = status['last_backup_time'] ?? 0;
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final elapsed = now - lastBackupTime;

          if (elapsed >= backupIntervalMinutes * 60) {
            final result = FFIBridge.triggerBackup();
            final contactCount = status['contact_count'] ?? 0;

            flutterLocalNotificationsPlugin.show(
              id: 888,
              title: 'Contacts Backup Active',
              body: 'Last backup: just now · $contactCount contacts',
              notificationDetails: const NotificationDetails(
                android: AndroidNotificationDetails(
                  'backup_daemon',
                  'Backup Daemon',
                  icon: '@mipmap/ic_launcher',
                  ongoing: true,
                  importance: Importance.low,
                  priority: Priority.low,
                  showWhen: false,
                ),
              ),
            );

            // Notify the UI
            service.invoke('backupUpdate', {
              "result": result,
              "timestamp": now,
            });
          } else {
            // Update notification with time since last backup
            final minutesAgo = elapsed ~/ 60;
            final contactCount = status['contact_count'] ?? 0;
            final timeStr = minutesAgo == 0 ? 'just now' : '$minutesAgo min ago';

            flutterLocalNotificationsPlugin.show(
              id: 888,
              title: 'Contacts Backup Active',
              body: 'Last backup: $timeStr · $contactCount contacts',
              notificationDetails: const NotificationDetails(
                android: AndroidNotificationDetails(
                  'backup_daemon',
                  'Backup Daemon',
                  icon: '@mipmap/ic_launcher',
                  ongoing: true,
                  importance: Importance.low,
                  priority: Priority.low,
                  showWhen: false,
                ),
              ),
            );
          }
        } catch (e) {
          debugPrint('Backup daemon error: $e');
        }
      }
    }
  });
}
