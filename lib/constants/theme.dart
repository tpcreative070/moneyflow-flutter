// lib/constants/theme.dart
import 'package:flutter/material.dart';

class AppColors {
  static const primaryPurple = Color(0xFF6C63FF);
  static const darkPurple    = Color(0xFF3D3494);
  static const incomeGreen   = Color(0xFF4ADE80);
  static const outcomeRed    = Color(0xFFF87171);
  static const warningOrange = Color(0xFFF97316);
  static const white         = Color(0xFFFFFFFF);
  static const black         = Color(0xFF000000);
  static const background    = Color(0xFFF5F5F5);
  static const cardBg        = Color(0xFFFFFFFF);
  static const textPrimary   = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted     = Color(0xFF9CA3AF);
  static const border        = Color(0xFFE5E7EB);
  static const divider       = Color(0xFFF3F4F6);
  static const success       = Color(0xFF22C55E);
  static const error         = Color(0xFFEF4444);
}

class AppRadius {
  static const double chip     = 10;
  static const double button   = 14;
  static const double card     = 16;
  static const double heroCard = 24;
  static const double full     = 9999;
}

class AppSpacing {
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 40;
}

class CurrencyInfo {
  final String code;
  final String symbol;
  final String displayName;
  final String flag;
  final bool suffix;
  final int decimals;

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.displayName,
    required this.flag,
    required this.suffix,
    required this.decimals,
  });
}

const List<CurrencyInfo> kCurrencies = [
  CurrencyInfo(code: 'VND', symbol: '₫',  displayName: 'Vietnamese Dong',  flag: '🇻🇳', suffix: true,  decimals: 0),
  CurrencyInfo(code: 'USD', symbol: '\$', displayName: 'US Dollar',         flag: '🇺🇸', suffix: false, decimals: 2),
  CurrencyInfo(code: 'EUR', symbol: '€',  displayName: 'Euro',              flag: '🇪🇺', suffix: false, decimals: 2),
  CurrencyInfo(code: 'JPY', symbol: '¥',  displayName: 'Japanese Yen',      flag: '🇯🇵', suffix: false, decimals: 0),
  CurrencyInfo(code: 'SGD', symbol: 'S\$',displayName: 'Singapore Dollar',  flag: '🇸🇬', suffix: false, decimals: 2),
  CurrencyInfo(code: 'GBP', symbol: '£',  displayName: 'British Pound',     flag: '🇬🇧', suffix: false, decimals: 2),
  CurrencyInfo(code: 'KRW', symbol: '₩',  displayName: 'Korean Won',        flag: '🇰🇷', suffix: false, decimals: 0),
  CurrencyInfo(code: 'CNY', symbol: '¥',  displayName: 'Chinese Yuan',      flag: '🇨🇳', suffix: false, decimals: 2),
  CurrencyInfo(code: 'THB', symbol: '฿',  displayName: 'Thai Baht',         flag: '🇹🇭', suffix: false, decimals: 2),
  CurrencyInfo(code: 'AUD', symbol: 'A\$',displayName: 'Australian Dollar', flag: '🇦🇺', suffix: false, decimals: 2),
];

class CategoryModel {
  final String id;
  final String name;
  final String type; // 'income' | 'outcome' | 'both'
  final String icon;
  final String colorHex;
  final bool isDefault;
  final String createdAt;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.colorHex,
    required this.isDefault,
    required this.createdAt,
  });

  CategoryModel copyWith({
    String? id, String? name, String? type,
    String? icon, String? colorHex, bool? isDefault, String? createdAt,
  }) => CategoryModel(
    id: id ?? this.id, name: name ?? this.name, type: type ?? this.type,
    icon: icon ?? this.icon, colorHex: colorHex ?? this.colorHex,
    isDefault: isDefault ?? this.isDefault, createdAt: createdAt ?? this.createdAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'type': type, 'icon': icon,
    'colorHex': colorHex, 'isDefault': isDefault ? 1 : 0, 'createdAt': createdAt,
  };

  factory CategoryModel.fromMap(Map<String, dynamic> m) => CategoryModel(
    id: m['id'], name: m['name'], type: m['type'], icon: m['icon'],
    colorHex: m['colorHex'], isDefault: m['isDefault'] == 1, createdAt: m['createdAt'],
  );
}

List<CategoryModel> get kDefaultCategories {
  final now = DateTime.now().toIso8601String();
  return [
    CategoryModel(id: 'cat_food',       name: 'Food & Dining',    type: 'outcome', icon: 'restaurant',             colorHex: '#FF6B6B', isDefault: true, createdAt: now),
    CategoryModel(id: 'cat_transport',  name: 'Transport',         type: 'outcome', icon: 'directions_car',         colorHex: '#4ECDC4', isDefault: true, createdAt: now),
    CategoryModel(id: 'cat_shopping',   name: 'Shopping',          type: 'outcome', icon: 'shopping_bag',           colorHex: '#45B7D1', isDefault: true, createdAt: now),
    CategoryModel(id: 'cat_health',     name: 'Health',            type: 'outcome', icon: 'local_hospital',         colorHex: '#96CEB4', isDefault: true, createdAt: now),
    CategoryModel(id: 'cat_entertain',  name: 'Entertainment',     type: 'outcome', icon: 'movie',                  colorHex: '#FFEAA7', isDefault: true, createdAt: now),
    CategoryModel(id: 'cat_bills',      name: 'Bills & Utilities', type: 'outcome', icon: 'receipt',                colorHex: '#DDA0DD', isDefault: true, createdAt: now),
    CategoryModel(id: 'cat_education',  name: 'Education',         type: 'outcome', icon: 'school',                 colorHex: '#98D8C8', isDefault: true, createdAt: now),
    CategoryModel(id: 'cat_salary',     name: 'Salary',            type: 'income',  icon: 'account_balance_wallet', colorHex: '#6C63FF', isDefault: true, createdAt: now),
    CategoryModel(id: 'cat_freelance',  name: 'Freelance',         type: 'income',  icon: 'laptop',                 colorHex: '#4ADE80', isDefault: true, createdAt: now),
    CategoryModel(id: 'cat_investment', name: 'Investment',        type: 'income',  icon: 'trending_up',            colorHex: '#F59E0B', isDefault: true, createdAt: now),
    CategoryModel(id: 'cat_gift',       name: 'Gift',              type: 'both',    icon: 'card_giftcard',          colorHex: '#EC4899', isDefault: true, createdAt: now),
    CategoryModel(id: 'cat_other',      name: 'Other',             type: 'both',    icon: 'more_horiz',             colorHex: '#9CA3AF', isDefault: true, createdAt: now),
  ];
}

const List<String> kIconOptions = [
  'restaurant','directions_car','shopping_bag','local_hospital','movie',
  'receipt','school','account_balance_wallet','laptop','trending_up',
  'card_giftcard','more_horiz','home','flight','fitness_center',
  'pets','music_note','sports_esports','spa','child_care',
  'local_grocery_store','local_gas_station','phone','wifi','build',
  'attach_money','savings','credit_card','local_atm','business',
];

const List<String> kColorOptions = [
  '#FF6B6B','#4ECDC4','#45B7D1','#96CEB4','#FFEAA7',
  '#DDA0DD','#98D8C8','#6C63FF','#4ADE80','#F59E0B',
  '#EC4899','#9CA3AF','#F97316','#06B6D4','#8B5CF6',
];

// Helper to parse hex color strings
Color hexColor(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

// Map icon name strings to IconData
IconData iconData(String name) {
  const map = <String, IconData>{
    'restaurant':             Icons.restaurant,
    'directions_car':         Icons.directions_car,
    'shopping_bag':           Icons.shopping_bag,
    'local_hospital':         Icons.local_hospital,
    'movie':                  Icons.movie,
    'receipt':                Icons.receipt,
    'school':                 Icons.school,
    'account_balance_wallet': Icons.account_balance_wallet,
    'laptop':                 Icons.laptop,
    'trending_up':            Icons.trending_up,
    'card_giftcard':          Icons.card_giftcard,
    'more_horiz':             Icons.more_horiz,
    'home':                   Icons.home,
    'flight':                 Icons.flight,
    'fitness_center':         Icons.fitness_center,
    'pets':                   Icons.pets,
    'music_note':             Icons.music_note,
    'sports_esports':         Icons.sports_esports,
    'spa':                    Icons.spa,
    'child_care':             Icons.child_care,
    'local_grocery_store':    Icons.local_grocery_store,
    'local_gas_station':      Icons.local_gas_station,
    'phone':                  Icons.phone,
    'wifi':                   Icons.wifi,
    'build':                  Icons.build,
    'attach_money':           Icons.attach_money,
    'savings':                Icons.savings,
    'credit_card':            Icons.credit_card,
    'local_atm':              Icons.local_atm,
    'business':               Icons.business,
  };
  return map[name] ?? Icons.more_horiz;
}