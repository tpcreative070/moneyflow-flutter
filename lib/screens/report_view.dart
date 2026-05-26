// lib/screens/report_view.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../context/store.dart';
import '../utils/currency.dart';
import '../utils/database.dart';
import '../utils/localization.dart';

const _pieColors = [
  Color(0xFF6C63FF), Color(0xFF4ADE80), Color(0xFFF87171),
  Color(0xFFF59E0B), Color(0xFF06B6D4), Color(0xFFEC4899),
];

class ReportView extends StatefulWidget {
  const ReportView({super.key});
  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  String _period    = 'month';
  String _chartType = 'bar';

  List<TransactionModel> _filtered(List<TransactionModel> all) {
    final now = DateTime.now();
    return all.where((tx) {
      final d = DateTime.parse(tx.date);
      switch (_period) {
        case 'week':  return now.difference(d).inDays <= 7;
        case 'month': return d.month == now.month && d.year == now.year;
        case 'year':  return d.year == now.year;
        default:      return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final loc          = context.watch<LocalizationProvider>();
    final code         = context.watch<CurrencyProvider>().code;
    final transactions = context.watch<TransactionProvider>().transactions;
    final filtered     = _filtered(transactions);

    final totalIncome  = filtered.where((t) => t.type == 'income').fold(0.0, (s, t) => s + t.amount);
    final totalOutcome = filtered.where((t) => t.type == 'outcome').fold(0.0, (s, t) => s + t.amount);
    final netBalance   = totalIncome - totalOutcome;
    final days         = _period == 'week' ? 7 : _period == 'month' ? 30 : 365;
    final avgDaily     = totalOutcome / (days > 0 ? days : 1);

    // Bar/Line data
    final grouped = <String, Map<String, double>>{};
    for (final tx in filtered) {
      final d = DateTime.parse(tx.date);
      final key = _period == 'year'
          ? _monthShort(d.month)
          : '${d.day}';
      grouped[key] ??= {'income': 0, 'outcome': 0};
      grouped[key]![tx.type] = (grouped[key]![tx.type] ?? 0) + tx.amount;
    }

    final barKeys = grouped.keys.toList();

    // Pie data
    final pieGroups = <String, double>{};
    for (final tx in filtered.where((t) => t.type == 'outcome')) {
      pieGroups[tx.categoryName] = (pieGroups[tx.categoryName] ?? 0) + tx.amount;
    }
    final pieData = pieGroups.entries.toList();

    // Category breakdown
    final breakGroups = <String, Map<String, dynamic>>{};
    for (final tx in filtered) {
      breakGroups[tx.categoryId] ??= {'name': tx.categoryName, 'total': 0.0, 'count': 0};
      breakGroups[tx.categoryId]!['total'] = (breakGroups[tx.categoryId]!['total'] as double) + tx.amount;
      breakGroups[tx.categoryId]!['count'] = (breakGroups[tx.categoryId]!['count'] as int) + 1;
    }
    final breakdown = breakGroups.values.toList()
      ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));

    final tiles = [
      (loc.str('netBalance'), netBalance, netBalance >= 0 ? AppColors.incomeGreen : AppColors.outcomeRed),
      (loc.str('income'),     totalIncome,  AppColors.incomeGreen),
      (loc.str('outcome'),    totalOutcome, AppColors.outcomeRed),
      (loc.str('avgDaily'),   avgDaily,     AppColors.textSecondary),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Period tabs
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Row(children: ['week','month','year'].map((p) => Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _period = p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _period == p ? AppColors.primaryPurple : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    alignment: Alignment.center,
                    child: Text(loc.str(p), style: TextStyle(
                        color: _period == p ? AppColors.white : AppColors.textSecondary,
                        fontWeight: _period == p ? FontWeight.w600 : FontWeight.normal)),
                  ),
                ),
              )).toList()),
            ),
          ),

          // Chart type
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final c in ['bar','line','pie']) ...[
              GestureDetector(
                onTap: () => setState(() => _chartType = c),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _chartType == c ? AppColors.primaryPurple : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(
                    c == 'bar' ? Icons.bar_chart : c == 'line' ? Icons.show_chart : Icons.pie_chart,
                    size: 20,
                    color: _chartType == c ? AppColors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 12),

          // Summary tiles
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 10, runSpacing: 10, children: tiles.map((t) => SizedBox(
              width: (MediaQuery.of(context).size.width - 42) / 2,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.$1, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(formatCompact(t.$2, code), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: t.$3)),
                ]),
              ),
            )).toList()),
          ),
          const SizedBox(height: 12),

          // Chart
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
            ),
            child: _buildChart(barKeys, grouped, pieData),
          ),
          const SizedBox(height: 16),

          // Category breakdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(loc.str('categoryBreakdown'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
            ),
            child: breakdown.isEmpty
                ? const Padding(padding: EdgeInsets.all(16),
                child: Text('No data', style: TextStyle(color: AppColors.textMuted)))
                : Column(children: breakdown.asMap().entries.map((e) {
              final i = e.key; final c = e.value;
              return Container(
                decoration: i > 0
                    ? const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider)))
                    : null,
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Expanded(child: Text(c['name'] as String,
                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary))),
                  Text('${c['count']} txns',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(width: 12),
                  Text(formatCompact(c['total'] as double, code),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ]),
              );
            }).toList()),
          ),
        ]),
      )),
    );
  }

  Widget _buildChart(
      List<String> keys,
      Map<String, Map<String, double>> grouped,
      List<MapEntry<String, double>> pieData,
      ) {
    if (_chartType == 'pie') {
      if (pieData.isEmpty) return _noData();
      return SizedBox(
        height: 250,
        child: PieChart(PieChartData(
          sections: pieData.asMap().entries.map((e) => PieChartSectionData(
            value: e.value.value,
            color: _pieColors[e.key % _pieColors.length],
            title: e.value.key.length > 8 ? '${e.value.key.substring(0, 7)}…' : e.value.key,
            titleStyle: const TextStyle(fontSize: 10, color: AppColors.white),
            radius: 80,
          )).toList(),
        )),
      );
    }

    if (keys.isEmpty) return _noData();

    final maxY = grouped.values.fold(0.0, (m, v) =>
    m < (v['income'] ?? 0) ? (v['income'] ?? 0) : m < (v['outcome'] ?? 0) ? (v['outcome'] ?? 0) : m);

    if (_chartType == 'bar') {
      return SizedBox(
        height: 250,
        child: BarChart(BarChartData(
          maxY: maxY * 1.2,
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= keys.length) return const SizedBox();
                return Text(keys[idx], style: const TextStyle(fontSize: 9));
              },
            )),
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, _) => Text(
                v >= 1000000 ? '${(v/1000000).toStringAsFixed(0)}M' :
                v >= 1000 ? '${(v/1000).toStringAsFixed(0)}K' : v.toStringAsFixed(0),
                style: const TextStyle(fontSize: 9),
              ),
            )),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: keys.asMap().entries.map((e) {
            final v = grouped[e.value]!;
            return BarChartGroupData(x: e.key, barRods: [
              BarChartRodData(toY: v['income'] ?? 0, color: AppColors.incomeGreen, width: 8, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
              BarChartRodData(toY: v['outcome'] ?? 0, color: AppColors.outcomeRed, width: 8, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
            ]);
          }).toList(),
        )),
      );
    }

    // Line
    return SizedBox(
      height: 250,
      child: LineChart(LineChartData(
        maxY: maxY * 1.2,
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) {
              final idx = v.toInt();
              if (idx < 0 || idx >= keys.length) return const SizedBox();
              return Text(keys[idx], style: const TextStyle(fontSize: 9));
            },
          )),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: keys.asMap().entries.map((e) =>
                FlSpot(e.key.toDouble(), grouped[e.value]!['income'] ?? 0)).toList(),
            color: AppColors.incomeGreen, isCurved: true, dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: keys.asMap().entries.map((e) =>
                FlSpot(e.key.toDouble(), grouped[e.value]!['outcome'] ?? 0)).toList(),
            color: AppColors.outcomeRed, isCurved: true, dotData: const FlDotData(show: false),
          ),
        ],
      )),
    );
  }

  Widget _noData() => const SizedBox(
    height: 200,
    child: Center(child: Text('No data for this period', style: TextStyle(color: AppColors.textMuted))),
  );

  String _monthShort(int m) =>
      ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];
}