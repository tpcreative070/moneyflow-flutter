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
  // FIX: use the store's DateFilter enum instead of a local string
  // so the report period is consistent with the filter engine in store.dart.
  DateFilter _period    = DateFilter.thisMonth;
  String     _chartType = 'bar';

  /// Filter transactions to the selected period.
  /// FIX: DateTime.parse replaced with tryParse to avoid crash on bad data.
  List<TransactionModel> _filtered(List<TransactionModel> all) {
    final now = DateTime.now();
    return all.where((tx) {
      final d = DateTime.tryParse(tx.date);
      if (d == null) return false;
      switch (_period) {
        case DateFilter.today:
          return d.year == now.year &&
              d.month == now.month &&
              d.day == now.day;
        case DateFilter.thisWeek:
          final startOfWeek = DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: now.weekday - 1));
          return !d.isBefore(startOfWeek);
        case DateFilter.thisMonth:
          return d.month == now.month && d.year == now.year;
        case DateFilter.thisYear:
          return d.year == now.year;
        case DateFilter.all:
          return true;
      }
    }).toList();
  }

  /// Number of calendar days in the selected period — used for avg daily.
  int get _periodDays {
    switch (_period) {
      case DateFilter.today:   return 1;
      case DateFilter.thisWeek: return 7;
      case DateFilter.thisMonth: return 30;
      case DateFilter.thisYear:  return 365;
      case DateFilter.all:       return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();
    final code = context.watch<CurrencyProvider>().code;

    // FIX: read from `transactions` (the full unfiltered list) since this
    // view manages its own independent period filter — not from
    // filteredTransactions which reflects the main list's filter state.
    final all      = context.watch<TransactionProvider>().transactions;
    final filtered = _filtered(all);

    final totalIncome  = filtered
        .where((t) => t.type == 'income')
        .fold(0.0, (s, t) => s + t.amount);
    final totalOutcome = filtered
        .where((t) => t.type == 'outcome')
        .fold(0.0, (s, t) => s + t.amount);
    final netBalance = totalIncome - totalOutcome;
    final avgDaily   = totalOutcome / _periodDays;

    // ── Bar / Line data ──────────────────────────────────────
    final grouped = <String, Map<String, double>>{};
    for (final tx in filtered) {
      final d   = DateTime.tryParse(tx.date);
      if (d == null) continue;
      final key = _period == DateFilter.thisYear
          ? _monthShort(d.month)
          : '${d.day}';
      grouped[key] ??= {'income': 0, 'outcome': 0};
      grouped[key]![tx.type] = (grouped[key]![tx.type] ?? 0) + tx.amount;
    }
    final barKeys = grouped.keys.toList();

    // ── Pie data ─────────────────────────────────────────────
    final pieGroups = <String, double>{};
    for (final tx in filtered.where((t) => t.type == 'outcome')) {
      pieGroups[tx.categoryName] =
          (pieGroups[tx.categoryName] ?? 0) + tx.amount;
    }
    final pieData = pieGroups.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // ── Category breakdown ────────────────────────────────────
    final breakGroups = <String, Map<String, dynamic>>{};
    for (final tx in filtered) {
      breakGroups[tx.categoryId] ??= {
        'name':  tx.categoryName,
        'total': 0.0,
        'count': 0,
        'type':  tx.type,
      };
      breakGroups[tx.categoryId]!['total'] =
          (breakGroups[tx.categoryId]!['total'] as double) + tx.amount;
      breakGroups[tx.categoryId]!['count'] =
          (breakGroups[tx.categoryId]!['count'] as int) + 1;
    }
    final breakdown = breakGroups.values.toList()
      ..sort((a, b) =>
          (b['total'] as double).compareTo(a['total'] as double));

    final tiles = [
      (loc.str('netBalance'), netBalance,
      netBalance >= 0 ? AppColors.incomeGreen : AppColors.outcomeRed),
      (loc.str('income'),  totalIncome,  AppColors.incomeGreen),
      (loc.str('outcome'), totalOutcome, AppColors.outcomeRed),
      (loc.str('avgDaily'), avgDaily,    AppColors.textSecondary),
    ];

    // ── Period tab labels ─────────────────────────────────────
    final periodTabs = <DateFilter, String>{
      DateFilter.thisWeek:  loc.str('week'),
      DateFilter.thisMonth: loc.str('month'),
      DateFilter.thisYear:  loc.str('year'),
      DateFilter.all:       loc.str('all'),
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Period tabs ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Row(
                children: periodTabs.entries.map((e) => Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _period = e.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _period == e.key
                            ? AppColors.primaryPurple
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                      ),
                      alignment: Alignment.center,
                      child: Text(e.value, style: TextStyle(
                          color: _period == e.key
                              ? AppColors.white
                              : AppColors.textSecondary,
                          fontWeight: _period == e.key
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 13)),
                    ),
                  ),
                )).toList(),
              ),
            ),
          ),

          // ── Chart type selector ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              for (final c in ['bar', 'line', 'pie']) ...[
                GestureDetector(
                  onTap: () => setState(() => _chartType = c),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _chartType == c
                          ? AppColors.primaryPurple
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(
                      c == 'bar'
                          ? Icons.bar_chart
                          : c == 'line'
                          ? Icons.show_chart
                          : Icons.pie_chart,
                      size: 20,
                      color: _chartType == c
                          ? AppColors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 12),

          // ── Summary tiles ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 10, runSpacing: 10,
              children: tiles.map((t) => SizedBox(
                width: (MediaQuery.of(context).size.width - 42) / 2,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.$1,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(formatCompact(t.$2, code),
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: t.$3)),
                    ],
                  ),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // ── Chart ────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.04), blurRadius: 4)],
            ),
            child: _buildChart(barKeys, grouped, pieData),
          ),
          const SizedBox(height: 16),

          // ── Pie legend (only shown for pie chart) ────────────
          if (_chartType == 'pie' && pieData.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(spacing: 12, runSpacing: 8,
                children: pieData.asMap().entries.map((e) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: _pieColors[e.key % _pieColors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(e.value.key,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ],
                )).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Category breakdown ───────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(loc.str('categoryBreakdown'),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ),
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.04), blurRadius: 4)],
            ),
            child: breakdown.isEmpty
                ? Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(loc.str('noData'),
                    style: const TextStyle(
                        color: AppColors.textMuted)),
              ),
            )
                : Column(
              children: breakdown.asMap().entries.map((e) {
                final i = e.key;
                final c = e.value;
                return Container(
                  decoration: i > 0
                      ? const BoxDecoration(
                      border: Border(
                          top: BorderSide(
                              color: AppColors.divider)))
                      : null,
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Expanded(
                      child: Text(c['name'] as String,
                          style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary)),
                    ),
                    Text('${c['count']} txns',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                    const SizedBox(width: 12),
                    Text(
                      formatCompact(c['total'] as double, code),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        // FIX: colour the amount by type
                        color: (c['type'] as String) == 'income'
                            ? AppColors.incomeGreen
                            : AppColors.outcomeRed,
                      ),
                    ),
                  ]),
                );
              }).toList(),
            ),
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
          sectionsSpace: 2,
          centerSpaceRadius: 32,
          sections: pieData.asMap().entries.map((e) {
            final total = pieData.fold(0.0, (s, x) => s + x.value);
            final pct   = total > 0
                ? (e.value.value / total * 100).toStringAsFixed(1)
                : '0';
            return PieChartSectionData(
              value:      e.value.value,
              color:      _pieColors[e.key % _pieColors.length],
              title:      '$pct%',
              titleStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white),
              radius: 80,
            );
          }).toList(),
        )),
      );
    }

    if (keys.isEmpty) return _noData();

    // FIX: original maxY nested ternary was incorrect — it only ever kept
    // one of income/outcome depending on the last comparison. Use fold properly.
    final maxY = grouped.values.fold(0.0, (m, v) {
      final inc = v['income']  ?? 0;
      final out = v['outcome'] ?? 0;
      return [m, inc, out].reduce((a, b) => a > b ? a : b);
    });

    if (_chartType == 'bar') {
      return SizedBox(
        height: 250,
        child: BarChart(BarChartData(
          maxY: maxY * 1.2 == 0 ? 100 : maxY * 1.2,
          gridData:   const FlGridData(show: true),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= keys.length) return const SizedBox();
                return Text(keys[idx],
                    style: const TextStyle(fontSize: 9));
              },
            )),
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, _) => Text(
                v >= 1000000
                    ? '${(v / 1000000).toStringAsFixed(0)}M'
                    : v >= 1000
                    ? '${(v / 1000).toStringAsFixed(0)}K'
                    : v.toStringAsFixed(0),
                style: const TextStyle(fontSize: 9),
              ),
            )),
            rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: keys.asMap().entries.map((e) {
            final v = grouped[e.value]!;
            return BarChartGroupData(x: e.key, barRods: [
              BarChartRodData(
                  toY: v['income'] ?? 0,
                  color: AppColors.incomeGreen,
                  width: 8,
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4))),
              BarChartRodData(
                  toY: v['outcome'] ?? 0,
                  color: AppColors.outcomeRed,
                  width: 8,
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4))),
            ]);
          }).toList(),
        )),
      );
    }

    // ── Line chart ───────────────────────────────────────────
    return SizedBox(
      height: 250,
      child: LineChart(LineChartData(
        maxY: maxY * 1.2 == 0 ? 100 : maxY * 1.2,
        gridData:   const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) {
              final idx = v.toInt();
              if (idx < 0 || idx >= keys.length) return const SizedBox();
              return Text(keys[idx],
                  style: const TextStyle(fontSize: 9));
            },
          )),
          leftTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: keys.asMap().entries
                .map((e) => FlSpot(e.key.toDouble(),
                grouped[e.value]!['income'] ?? 0))
                .toList(),
            color:    AppColors.incomeGreen,
            isCurved: true,
            dotData:  const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.incomeGreen.withOpacity(0.08),
            ),
          ),
          LineChartBarData(
            spots: keys.asMap().entries
                .map((e) => FlSpot(e.key.toDouble(),
                grouped[e.value]!['outcome'] ?? 0))
                .toList(),
            color:    AppColors.outcomeRed,
            isCurved: true,
            dotData:  const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.outcomeRed.withOpacity(0.08),
            ),
          ),
        ],
      )),
    );
  }

  Widget _noData() => const SizedBox(
    height: 200,
    child: Center(
      child: Text('No data for this period',
          style: TextStyle(color: AppColors.textMuted)),
    ),
  );

  String _monthShort(int m) =>
      ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];
}