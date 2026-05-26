// lib/utils/currency.dart
import '../constants/theme.dart';
import 'package:intl/intl.dart';

CurrencyInfo getCurrency(String code) =>
    kCurrencies.firstWhere((c) => c.code == code, orElse: () => kCurrencies.first);

String formatAmount(double amount, String code) {
  final cur = getCurrency(code);
  final val = amount.abs();
  final formatter = NumberFormat.currency(
    symbol: '',
    decimalDigits: cur.decimals,
  );
  final formatted = formatter.format(val).trim();
  return cur.suffix ? '$formatted ${cur.symbol}' : '${cur.symbol}$formatted';
}

String formatCompact(double amount, String code) {
  final cur = getCurrency(code);
  final val = amount.abs();
  String compact;
  if (val >= 1000000000) {
    compact = '${(val / 1000000000).toStringAsFixed(1)}B';
  } else if (val >= 1000000) {
    compact = '${(val / 1000000).toStringAsFixed(1)}M';
  } else if (val >= 1000) {
    compact = '${(val / 1000).toStringAsFixed(1)}K';
  } else {
    compact = val.round().toString();
  }
  return cur.suffix ? '$compact${cur.symbol}' : '${cur.symbol}$compact';
}