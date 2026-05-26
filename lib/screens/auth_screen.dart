// lib/screens/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// FIX: Hide Firebase's built-in `AuthProvider` to avoid the name conflict
// with our own `AuthProvider` from `store.dart`.
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:google_sign_in/google_sign_in.dart';
import '../constants/theme.dart';
import '../context/store.dart';
import '../utils/localization.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _loading = false;
  String _error = '';

  final _googleSignIn = GoogleSignIn(
    // Replace with your Web client ID from Google Cloud Console
    clientId: '382775998205-0apkrdavr3oe2ia50j3vfhebt8adbh2k.apps.googleusercontent.com',
    scopes: ['email'],
  );

  Future<void> _handleGoogle() async {
    setState(() { _error = ''; _loading = true; });
    try {
      await _googleSignIn.signOut(); // force account picker
      final account = await _googleSignIn.signIn();
      if (account == null) { setState(() => _loading = false); return; }

      final auth       = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken:     auth.idToken,
        accessToken: auth.accessToken,
      );
      final result = await FirebaseAuth.instance.signInWithCredential(credential);
      final u = result.user!;
      if (mounted) {
        context.read<AuthProvider>().setUser(UserModel(
          uid: u.uid,
          displayName: u.displayName ?? 'User',
          email: u.email ?? '',
          photoURL: u.photoURL,
        ));
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Firebase auth failed');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleGuest() => context.read<AuthProvider>().setGuest();

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();
    final features = [
      (Icons.bar_chart,     'Daily income / expense tracking'),
      (Icons.notifications, 'Budget exceeded alerts'),
      (Icons.cloud,         'Cloud data sync'),
      (Icons.wifi_off,      'Offline support'),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryPurple, AppColors.darkPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
            child: Column(
              children: [
                // Logo
                Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_wallet, size: 56, color: AppColors.white),
                ),
                const SizedBox(height: 16),
                Text(loc.str('appName'),
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.white)),
                const SizedBox(height: 4),
                Text(loc.str('appSubtitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8))),
                const SizedBox(height: 36),

                // Features
                ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Icon(f.$1, size: 22, color: AppColors.white),
                    const SizedBox(width: 12),
                    Text(f.$2, style: const TextStyle(color: AppColors.white, fontSize: 15)),
                  ]),
                )),
                const SizedBox(height: 36),

                // Buttons
                if (_loading)
                  const CircularProgressIndicator(color: AppColors.white)
                else ...[
                  // Google Button
                  _AuthButton(
                    onTap: _handleGoogle,
                    backgroundColor: AppColors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                            color: AppColors.primaryPurple)),
                        const SizedBox(width: 10),
                        Text(loc.str('signInGoogle'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                                color: AppColors.primaryPurple)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Divider
                  Row(children: [
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(loc.str('orLabel'),
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
                    ),
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
                  ]),
                  const SizedBox(height: 12),

                  // Guest Button
                  _AuthButton(
                    onTap: _handleGuest,
                    backgroundColor: Colors.transparent,
                    border: Border.all(color: AppColors.white, width: 1.5),
                    child: Text(loc.str('continueGuest'),
                        style: const TextStyle(color: AppColors.white,
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ],

                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFFFB3B3), fontSize: 14)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color backgroundColor;
  final BoxBorder? border;
  final Widget child;

  const _AuthButton({
    required this.onTap,
    required this.backgroundColor,
    required this.child,
    this.border,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 54,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: border,
      ),
      alignment: Alignment.center,
      child: child,
    ),
  );
}