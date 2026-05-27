// lib/main.dart
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'constants/theme.dart';
import 'context/store.dart';
import 'screens/auth_screen.dart';
import 'screens/main_view.dart';
import 'screens/report_view.dart';
import 'screens/settings_view.dart';
import 'utils/localization.dart';

// ─────────────────────────────────────────────────────────────
//  Entry point
// ─────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // FIX: two-layer protection around Firebase init:
  //   1. try/catch  — handles thrown exceptions (bad config, missing file)
  //   2. .timeout() — handles silent hangs (no internet on cold start,
  //      DNS blocked, emulator with no Play Services)
  //   Without the timeout, Firebase.initializeApp() can block forever
  //   and runApp() is never reached — leaving the app on the white
  //   Flutter-logo splash screen indefinitely.
  //
  // IMPORTANT: we no longer silently continue when Firebase fails.
  // Swallowing the error caused a deferred [core/no-app] crash the moment
  // any Firebase service (Auth, Firestore) was first accessed.  Instead we
  // surface a clear error screen so the developer can act on the real cause
  // (missing / wrong GoogleService-Info.plist on iOS, google-services.json
  // on Android, or a network problem during cold start).
  String? firebaseError;
  try {
    await Firebase.initializeApp()
        .timeout(const Duration(seconds: 8));
  } on TimeoutException catch (e) {
    firebaseError = 'Firebase init timed out (no network on cold start?)\n$e';
    debugPrint('[main] $firebaseError');
  } catch (e) {
    firebaseError = e.toString();
    debugPrint('[main] Firebase init error: $firebaseError');
  }

  runApp(MoneyFlowApp(firebaseError: firebaseError));
}

// ─────────────────────────────────────────────────────────────
//  Root widget — registers every provider
// ─────────────────────────────────────────────────────────────
class MoneyFlowApp extends StatelessWidget {
  const MoneyFlowApp({super.key, this.firebaseError});

  /// Non-null when Firebase.initializeApp() failed or timed out.
  /// We display a clear error screen instead of running without Firebase
  /// (which previously caused a deferred [core/no-app] crash).
  final String? firebaseError;

  @override
  Widget build(BuildContext context) {
    // Show a human-readable error instead of a confusing [core/no-app] crash.
    if (firebaseError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _FirebaseErrorScreen(error: firebaseError!),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocalizationProvider()),
        ChangeNotifierProvider(create: (_) => CurrencyProvider()..init()),
        ChangeNotifierProvider(create: (_) => NetworkProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
      ],
      child: Consumer<LocalizationProvider>(
        builder: (_, loc, __) => MaterialApp(
          title: 'MoneyFlow',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primaryPurple,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: AppColors.background,
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              titleTextStyle: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              iconTheme: IconThemeData(color: AppColors.textPrimary),
            ),
          ),
          home: const _AppGate(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Firebase error screen
//  Shown instead of running the app without Firebase, which
//  previously caused a deferred [core/no-app] crash.
// ─────────────────────────────────────────────────────────────
class _FirebaseErrorScreen extends StatelessWidget {
  const _FirebaseErrorScreen({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryPurple, AppColors.darkPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: AppColors.white),
                const SizedBox(height: 20),
                const Text(
                  'Firebase could not start',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Common causes on iOS:\n'
                      '• GoogleService-Info.plist missing from ios/Runner/\n'
                      '• Plist not added to Xcode target (Copy Bundle Resources)\n'
                      '• Bundle ID in plist does not match the app\n\n'
                      'Common causes on Android:\n'
                      '• google-services.json missing from android/app/\n'
                      '• Package name mismatch',
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 13, color: AppColors.white, height: 1.6),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    error,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.white,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Auth gate
//  - isLoading  → branded splash (Firebase resolving session)
//  - no user, no guest → AuthScreen
//  - logged in or guest → load DB then show tabbed shell
// ─────────────────────────────────────────────────────────────
class _AppGate extends StatefulWidget {
  const _AppGate();
  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  bool _dataLoaded = false;

  Future<void> _loadData() async {
    if (_dataLoaded) return;
    _dataLoaded = true;

    // Step 1: Load local SQLite data first so the UI is immediately responsive.
    await Future.wait([
      context.read<CategoryProvider>().load(),
      context.read<TransactionProvider>().load(),
      context.read<BudgetProvider>().load(),
    ]);

    // Step 2: For authenticated (non-guest) users, pull latest data from
    // Firestore and flush any locally queued pending changes.
    // FIX: fetchFromFirestore and syncPending were never called anywhere,
    // which is why the app never synced with Firestore on open or after
    // adding a transaction while offline.
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid != null && uid != 'guest_demo') {
      await context.read<TransactionProvider>().fetchFromFirestore(uid);
      await context.read<TransactionProvider>().syncPending(uid: uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Still resolving persisted Firebase session
    if (auth.isLoading) {
      return const _SplashScreen();
    }

    // Not signed in and not a guest
    if (auth.user == null && !auth.isGuest) {
      _dataLoaded = false;
      return const AuthScreen();
    }

    // Authenticated — load local DB data then show app
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
    return const _TabbedShell();
  }
}

// ─────────────────────────────────────────────────────────────
//  Bottom-tab shell: Transactions | Reports | Settings
// ─────────────────────────────────────────────────────────────
class _TabbedShell extends StatefulWidget {
  const _TabbedShell();
  @override
  State<_TabbedShell> createState() => _TabbedShellState();
}

class _TabbedShellState extends State<_TabbedShell> {
  int _tab = 0;

  // FIX: was `static const _pages = [...]` — a compile-time constant list
  // means all three widgets are constructed once and never rebuilt.
  // Stateful widgets (ReportView, SettingsView) stored in a const list
  // cannot hold mutable state or respond to provider updates correctly
  // when hosted inside an IndexedStack.
  // Changed to a regular instance getter so each build gets fresh widgets
  // that are properly wired into the widget tree.
  List<Widget> get _pages => const [
    MainView(),
    ReportView(),
    SettingsView(),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _tab, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        selectedItemColor: AppColors.primaryPurple,
        unselectedItemColor: AppColors.textSecondary,
        backgroundColor: AppColors.white,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle:
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.receipt_long_outlined),
            activeIcon: const Icon(Icons.receipt_long),
            label: loc.str('transactions'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bar_chart_outlined),
            activeIcon: const Icon(Icons.bar_chart),
            label: loc.str('reports'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings),
            label: loc.str('settings'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Branded splash screen
// ─────────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryPurple, AppColors.darkPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance_wallet,
                size: 72,
                color: AppColors.white,
              ),
              SizedBox(height: 20),
              Text(
                'MoneyFlow',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: 40),
              CircularProgressIndicator(
                color: AppColors.white,
                strokeWidth: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}