// lib/screens/transaction_detail_view.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../context/store.dart';
import '../utils/currency.dart';
import '../utils/database.dart';
import '../utils/localization.dart';

class TransactionDetailView extends StatelessWidget {
  final TransactionModel tx;
  final VoidCallback onClose;
  final void Function(TransactionModel) onEdit;
  final void Function(TransactionModel) onDelete;

  const TransactionDetailView({
    super.key,
    required this.tx,
    required this.onClose,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final loc      = context.watch<LocalizationProvider>();
    final code     = context.watch<CurrencyProvider>().code;
    final isIncome = tx.type == 'income';
    final gradients = isIncome
        ? [const Color(0xFF4ADE80), const Color(0xFF22C55E)]
        : [const Color(0xFFF87171), const Color(0xFFEF4444)];

    final rows = [
      (Icons.calendar_today, loc.str('date'),
      DateFormat.yMMMMEEEEd().format(DateTime.parse(tx.date))),
      (Icons.category, loc.str('category'), tx.categoryName),
      if (tx.note.isNotEmpty) (Icons.notes, loc.str('note'), tx.note),
      (Icons.cloud_done, loc.str('syncStatus'),
      tx.synced ? loc.str('synced') : loc.str('pending')),
      (Icons.access_time, loc.str('createdAt'),
      DateFormat.yMMMd().add_Hm().format(DateTime.parse(tx.createdAt))),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // Top bar
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.close, color: AppColors.textPrimary),
              onPressed: onClose,
            ),
          ),

          // FIX: SingleChildScrollView takes a single `child`, not `children`.
          // Wrap the list of widgets in a Column and pass that as `child`.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Hero
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: gradients),
                        borderRadius: BorderRadius.circular(AppRadius.heroCard),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(children: [
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                            size: 32, color: AppColors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(tx.categoryName,
                            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(
                          '${isIncome ? '+' : '−'}${formatAmount(tx.amount, code)}',
                          style: const TextStyle(color: AppColors.white, fontSize: 38, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            isIncome ? loc.str('income') : loc.str('expense'),
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: isIncome ? AppColors.incomeGreen : AppColors.outcomeRed,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),

                  // Detail rows
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Column(children: rows.asMap().entries.map((e) {
                      final i = e.key; final row = e.value;
                      return Container(
                        decoration: i > 0
                            ? const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider)))
                            : null,
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.primaryPurple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(row.$1, size: 18, color: AppColors.primaryPurple),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(row.$2, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(height: 1),
                            Text(row.$3, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
                          ])),
                        ]),
                      );
                    }).toList()),
                  ),
                  const SizedBox(height: 16),

                  // Receipt
                  if (tx.attachmentBase64 != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        child: Image.memory(
                          base64Decode(tx.attachmentBase64!),
                          width: double.infinity, height: 200, fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),

          // Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Column(children: [
              _ActionBtn(
                onTap: () => onEdit(tx),
                color: AppColors.primaryPurple.withOpacity(0.1),
                icon: Icons.edit, iconColor: AppColors.primaryPurple,
                label: loc.str('editTransaction'),
                textColor: AppColors.primaryPurple,
              ),
              const SizedBox(height: 10),
              _ActionBtn(
                onTap: () => onDelete(tx),
                color: AppColors.error.withOpacity(0.1),
                icon: Icons.delete, iconColor: AppColors.error,
                label: loc.str('deleteTransaction'),
                textColor: AppColors.error,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color textColor;
  const _ActionBtn({required this.onTap, required this.color, required this.icon,
    required this.iconColor, required this.label, required this.textColor});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppRadius.button)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 15)),
      ]),
    ),
  );
}