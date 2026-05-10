import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:google_fonts/google_fonts.dart';
import 'features/contacts/contact_list_page.dart';
import 'features/dialer/dialer_page.dart';
import 'features/backup/backup_page.dart';
import 'core/ffi_bridge.dart';
import 'core/backup_daemon.dart';
import 'core/call_service.dart';
import 'core/contact_service.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> requestPermissions() async {
  // Request Notification permission (Android 13+)
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }

  // Request storage permission for backup folder access
  if (await Permission.storage.isDenied) {
    await Permission.storage.request();
  }

  // Request ignore battery optimizations (for reliable background backup)
  if (await Permission.ignoreBatteryOptimizations.isDenied) {
    await Permission.ignoreBatteryOptimizations.request();
  }

  // Phone permissions for calling features
  await [
    Permission.phone,
    Permission.microphone,
    Permission.contacts,
  ].request();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await requestPermissions();
    await FFIBridge.load();
    await initializeBackupDaemon();
    CallService().initialize();
    
    // Sync with system contacts on start
    unawaited(ContactSyncService().syncWithSystem());
  } catch (e) {
    debugPrint('Startup error: $e');
  }

  runApp(const ContactsApp());
}

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ContactsApp extends StatelessWidget {
  const ContactsApp({super.key});

  // Vibrant Kite-inspired palette
  static const _kiteBlue = Color(0xFF2A75D3); // Deeper, more vibrant blue
  static const _kiteRed = Color(0xFFE53935); // Sharper red

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, ThemeMode currentMode, child) {
        return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            // Curated Kite-like schemes (Clean, professional)
            final darkScheme = darkDynamic ??
                ColorScheme.fromSeed(
                  seedColor: _kiteBlue,
                  brightness: Brightness.dark,
                  surface: const Color(0xFF121212),
                  error: _kiteRed,
                );
            final lightScheme = lightDynamic ??
                ColorScheme.fromSeed(
                  seedColor: _kiteBlue,
                  brightness: Brightness.light,
                  surface: Colors.white,
                  error: _kiteRed,
                );

              return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Contacts Go',
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: lightScheme,
                textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
                scaffoldBackgroundColor: lightScheme.surface,
                splashFactory: InkSparkle.splashFactory,
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                colorScheme: darkScheme,
                textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
                scaffoldBackgroundColor: darkScheme.surface,
                splashFactory: InkSparkle.splashFactory,
              ),
              themeMode: currentMode,
              navigatorKey: navigatorKey,
              home: const MainNavigation(),
            );
          },
        );
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    ContactListPage(),
    DialerPage(),
    BackupPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 12.0, left: 20.0, right: 20.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey<int>(_selectedIndex),
              child: _pages[_selectedIndex],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(bottom: 24.0),
            decoration: BoxDecoration(
              color: colors.surface, // Clean solid background
              border: Border(top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.1), width: 1.0)),
            ),
            child: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
              animationDuration: const Duration(milliseconds: 400),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
              indicatorColor: colors.primary.withValues(alpha: 0.15),
              height: 64,
              elevation: 0,
              backgroundColor: Colors.transparent,
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.contacts_outlined, size: 28, color: colors.onSurfaceVariant),
                  selectedIcon: Icon(Icons.contacts, size: 28, color: colors.primary),
                  label: 'Contacts',
                ),
                NavigationDestination(
                  icon: Icon(Icons.dialpad_outlined, size: 28, color: colors.onSurfaceVariant),
                  selectedIcon: Icon(Icons.dialpad, size: 28, color: colors.primary),
                  label: 'Dialer',
                ),
                NavigationDestination(
                  icon: Icon(Icons.backup_outlined, size: 28, color: colors.onSurfaceVariant),
                  selectedIcon: Icon(Icons.backup_rounded, size: 28, color: colors.primary),
                  label: 'Backup',
                ),
              ],
            ),
          ),
    );
  }
}
