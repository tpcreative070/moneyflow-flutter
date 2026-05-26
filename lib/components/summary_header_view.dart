// lib/components/summary_header_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../context/store.dart';
import '../utils/currency.dart';
import '../utils/localization.dart';

class SummaryHeaderView extends StatelessWidget {
  final double balance;
  final double totalIncome;
  final double totalOutcome;

  const SummaryHeaderView({
    super.key,
    required this.balance,
    required this.totalIncome,
    required this.totalOutcome,
  });

  @override
  Widget build(BuildContext context) {
    final loc  = context.watch<LocalizationProvider>();
    final code = context.watch<CurrencyProvider>().code;

    return Container(
      height: 170,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryPurple, AppColors.darkPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(loc.str('balance'),
                style: const TextStyle(color: Color(0xBFFFFFFF), fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              formatCompact(balance, code),
              style: const TextStyle(color: AppColors.white, fontSize: 34, fontWeight: FontWeight.bold),
              maxLines: 1,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _Pill(
                  icon: Icons.arrow_downward,
                  label: loc.str('income'),
                  amount: formatCompact(totalIncome, code),
                  color: AppColors.incomeGreen,
                )),
                Container(width: 1, height: 36,
                    color: Colors.white.withOpacity(0.25)),
                Expanded(child: _Pill(
                  icon: Icons.arrow_upward,
                  label: loc.str('outcome'),
                  amount: formatCompact(totalOutcome, code),
                  color: AppColors.outcomeRed,
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String amount;
  final Color color;

  const _Pill({required this.icon, required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13)),
      const SizedBox(width: 4),
      Text(amount, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
    ],
  );
}