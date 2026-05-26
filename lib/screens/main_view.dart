// lib/screens/main_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../context/store.dart';
import '../utils/database.dart';
import '../utils/localization.dart';
import '../components/summary_header_view.dart';
import 'add_transaction_view.dart';
import 'transaction_detail_view.dart';

bool _inPeriod(TransactionModel tx, String filter) {
  final now = DateTime.now();
  final d   = DateTime.parse(tx.date);
  switch (filter) {
    case 'today':
      return d.year == now.year && d.month == now.month && d.day == now.day;
    case 'thisWeek':
      final s = now.subtract(Duration(days: now.weekday - 1));
      return d.isAfter(s.subtract(const Duration(days: 1)));
    case 'thisMonth':
      return d.month == now.month && d.year == now.year;
    case 'thisYear':
      return d.year == now.year;
    default:
      return true;
  }
}

class MainView extends StatefulWidget {
  const MainView({super.key});
  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  String _datePeriod = 'thisMonth';
  String _typeFilter = 'all';
  final _searchCtrl  = TextEditingController();
  String _search     = '';

  final _periods = ['today', 'thisWeek', 'thisMonth', 'thisYear'];

  List<TransactionModel> _filtered(List<TransactionModel> all) => all
      .where((tx) => _inPeriod(tx, _datePeriod))
      .where((tx) => _typeFilter == 'all' || tx.type == _typeFilter)
      .where((tx) => _search.isEmpty ||
      tx.categoryName.toLowerCase().contains(_search.toLowerCase()) ||
      tx.note.toLowerCase().contains(_search.toLowerCase()))
      .toList();

  Map<String, List<TransactionModel>> _grouped(List<TransactionModel> list) {
    final groups = <String, List<TransactionModel>>{};
    for (final tx in list) {
      final d = DateTime.parse(tx.date);
      final key = '${_dayName(d.weekday)}, ${d.day}/${d.month}/${d.year}';
      (groups[key] ??= []).add(tx);
    }
    return groups;
  }

  String _dayName(int wd) => ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][wd - 1];

  void _confirmDelete(BuildContext ctx, TransactionModel tx) {
    final loc = ctx.read<LocalizationProvider>();
    showDialog(context: ctx, builder: (_) => AlertDialog(
      title: Text(loc.str('confirmDelete')),
      content: Text(loc.str('cannotUndo')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.str('cancel'))),
        TextButton(
          onPressed: () { Navigator.pop(ctx); ctx.read<TransactionProvider>().remove(tx.id); },
          child: Text(loc.str('delete'), style: const TextStyle(color: AppColors.error)),
        ),
      ],
    ));
  }

  void _openAdd(BuildContext ctx, {TransactionModel? editTx}) {
    Navigator.push(ctx, MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AddTransactionView(editTx: editTx),
    ));
  }

  void _openDetail(BuildContext ctx, TransactionModel tx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TransactionDetailView(
        tx: tx,
        onClose: () => Navigator.pop(ctx),
        onEdit: (t) { Navigator.pop(ctx); _openAdd(ctx, editTx: t); },
        onDelete: (t) { Navigator.pop(ctx); _confirmDelete(ctx, t); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc          = context.watch<LocalizationProvider>();
    final transactions = context.watch<TransactionProvider>().transactions;
    final filtered     = _filtered(transactions);

    final totalIncome  = filtered.where((t) => t.type == 'income').fold(0.0, (s, t) => s + t.amount);
    final totalOutcome = filtered.where((t) => t.type == 'outcome').fold(0.0, (s, t) => s + t.amount);
    final grouped      = _grouped(filtered);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(children: [
        Column(children: [
          SummaryHeaderView(
            balance: totalIncome - totalOutcome,
            totalIncome: totalIncome,
            totalOutcome: totalOutcome,
          ),

          // Filter bar
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(children: [
              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: loc.str('search'),
                      hintStyle: const TextStyle(color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),

              // Date period chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 10, bottom: 4),
                child: Row(children: _periods.map((f) => _Chip(
                  label: loc.str(f),
                  active: _datePeriod == f,
                  onTap: () => setState(() => _datePeriod = f),
                )).toList()),
              ),

              // Type filter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(children: ['all','income','outcome'].map((t) => _Chip(
                  label: loc.str(t),
                  active: _typeFilter == t,
                  onTap: () => setState(() => _typeFilter = t),
                )).toList()),
              ),
            ]),
          ),

          // List
          Expanded(child: filtered.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.inbox, size: 52, color: AppColors.primaryPurple.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(loc.str('noTransactions'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(loc.str('addFirst'),
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ]))
              : ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: grouped.entries.map((entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(entry.key,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ),
                ...entry.value.map((tx) => _TxRow(
                  tx: tx,
                  onTap: () => _openDetail(context, tx),
                  onEdit: () => _openAdd(context, editTx: tx),
                  onDelete: () => _confirmDelete(context, tx),
                )),
              ],
            )).toList(),
          ),
          ),
        ]),

        // FAB
        Positioned(
          bottom: 20, right: 20,
          child: GestureDetector(
            onTap: () => _openAdd(context),
            child: const Icon(Icons.add_circle, size: 58, color: AppColors.primaryPurple),
          ),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppColors.primaryPurple : AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: active ? AppColors.primaryPurple : AppColors.border),
      ),
      child: Text(label,
          style: TextStyle(
            fontSize: 13,
            color: active ? AppColors.white : AppColors.textSecondary,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          )),
    ),
  );
}

class _TxRow extends StatelessWidget {
  final TransactionModel tx;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _TxRow({required this.tx, required this.onTap, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.type == 'income';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(children: [
        Expanded(child: GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: isIncome ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 22,
                  color: isIncome ? AppColors.incomeGreen : AppColors.outcomeRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tx.categoryName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                if (tx.note.isNotEmpty)
                  Text(tx.note, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Text(
                  '${DateTime.parse(tx.date).hour.toString().padLeft(2, '0')}:'
                      '${DateTime.parse(tx.date).minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
              ])),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                    '${isIncome ? '+' : '−'}${tx.amount.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: isIncome ? AppColors.incomeGreen : AppColors.outcomeRed),
                  ),
                  if (!tx.synced) const Icon(Icons.cloud_off, size: 12, color: AppColors.warningOrange),
                ]),
              ),
            ]),
          ),
        )),
        Column(children: [
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit, size: 18, color: AppColors.primaryPurple)),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete, size: 18, color: AppColors.error)),
        ]),
      ]),
    );
  }
}