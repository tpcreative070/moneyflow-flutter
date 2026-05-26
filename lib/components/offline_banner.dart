// lib/components/offline_banner.dart
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../context/store.dart';
import '../utils/localization.dart';

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slide = Tween<Offset>(
      begin: const Offset(0, -2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Connectivity().onConnectivityChanged.listen((result) {
      final connected = result != ConnectivityResult.none;
      context.read<NetworkProvider>().setConnected(connected);
      if (!connected) _ctrl.forward();
      else _ctrl.reverse();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();
    return Positioned(
      top: 8, left: 24, right: 24,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.warningOrange,
              borderRadius: BorderRadius.circular(AppRadius.full),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off, size: 15, color: AppColors.white),
                const SizedBox(width: 8),
                Text(loc.str('workingOffline'),
                    style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}