// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'constants/theme.dart';
import 'context/store.dart';
import 'utils/localization.dart';
import 'screens/auth_screen.dart';
import 'screens/main_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MoneyFlowApp());
}

class MoneyFlowApp extends StatelessWidget {
  const MoneyFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CurrencyProvider()..init()),
        ChangeNotifierProvider(create: (_) => NetworkProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ChangeNotifierProvider(create: (_) => LocalizationProvider()),
      ],
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  late final Connectivity _connectivity;

  @override
  void initState() {
    super.initState();
    _connectivity = Connectivity();

    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen((result) {
      final isConnected = result != ConnectivityResult.none;
      if (mounted) {
        context.read<NetworkProvider>().setConnected(isConnected);
        // Auto-sync when coming back online
        if (isConnected) {
          context.read<TransactionProvider>().syncPending();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoneyFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.primaryPurple,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'SF Pro Display',
      ),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Show auth screen if no user and not guest
    if (auth.user == null) {
      return const AuthScreen();
    }

    // User is logged in (Google or guest) — load data then show main view
    return const _DataLoader();
  }
}

class _DataLoader extends StatefulWidget {
  const _DataLoader();

  @override
  State<_DataLoader> createState() => _DataLoaderState();
}

class _DataLoaderState extends State<_DataLoader> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Future.wait([
      context.read<CategoryProvider>().load(),
      context.read<TransactionProvider>().load(),
      context.read<BudgetProvider>().load(),
      context.read<CurrencyProvider>().init(),
    ]);
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }
    return const MainView();
  }
}