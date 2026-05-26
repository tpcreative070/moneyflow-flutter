// lib/utils/database.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../constants/theme.dart';

class TransactionModel {
  final String id;
  final double amount;
  final String date;
  final String note;
  final String categoryId;
  final String categoryName;
  final String type;
  final String walletId;
  final bool synced;
  final String? attachmentBase64;
  final String createdAt;
  final String updatedAt;

  const TransactionModel({
    required this.id,
    required this.amount,
    required this.date,
    this.note = '',
    required this.categoryId,
    required this.categoryName,
    required this.type,
    this.walletId = 'default',
    this.synced = false,
    this.attachmentBase64,
    required this.createdAt,
    required this.updatedAt,
  });

  TransactionModel copyWith({
    String? id, double? amount, String? date, String? note,
    String? categoryId, String? categoryName, String? type,
    String? walletId, bool? synced, String? attachmentBase64,
    String? createdAt, String? updatedAt,
  }) => TransactionModel(
    id: id ?? this.id, amount: amount ?? this.amount,
    date: date ?? this.date, note: note ?? this.note,
    categoryId: categoryId ?? this.categoryId,
    categoryName: categoryName ?? this.categoryName,
    type: type ?? this.type, walletId: walletId ?? this.walletId,
    synced: synced ?? this.synced,
    attachmentBase64: attachmentBase64 ?? this.attachmentBase64,
    createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'amount': amount, 'date': date, 'note': note,
    'categoryId': categoryId, 'categoryName': categoryName,
    'type': type, 'walletId': walletId, 'synced': synced ? 1 : 0,
    'attachmentBase64': attachmentBase64,
    'createdAt': createdAt, 'updatedAt': updatedAt,
  };

  factory TransactionModel.fromMap(Map<String, dynamic> m) => TransactionModel(
    id: m['id'], amount: (m['amount'] as num).toDouble(),
    date: m['date'], note: m['note'] ?? '',
    categoryId: m['categoryId'], categoryName: m['categoryName'],
    type: m['type'], walletId: m['walletId'] ?? 'default',
    synced: m['synced'] == 1,
    attachmentBase64: m['attachmentBase64'],
    createdAt: m['createdAt'], updatedAt: m['updatedAt'],
  );
}

class BudgetRecord {
  final double monthlyLimit;
  final double yearlyLimit;
  final double notifyAt;

  const BudgetRecord({
    this.monthlyLimit = 0,
    this.yearlyLimit = 0,
    this.notifyAt = 0.8,
  });

  BudgetRecord copyWith({double? monthlyLimit, double? yearlyLimit, double? notifyAt}) =>
      BudgetRecord(
        monthlyLimit: monthlyLimit ?? this.monthlyLimit,
        yearlyLimit: yearlyLimit ?? this.yearlyLimit,
        notifyAt: notifyAt ?? this.notifyAt,
      );
}

class AppDatabase {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'moneyflow.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS transactions (
      id TEXT PRIMARY KEY, amount REAL NOT NULL, date TEXT NOT NULL,
      note TEXT DEFAULT '', categoryId TEXT NOT NULL, categoryName TEXT NOT NULL,
      type TEXT NOT NULL, walletId TEXT DEFAULT 'default',
      synced INTEGER DEFAULT 0, attachmentBase64 TEXT,
      createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS categories (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL,
      icon TEXT NOT NULL, colorHex TEXT NOT NULL,
      isDefault INTEGER DEFAULT 0, createdAt TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS budgets (
      id TEXT PRIMARY KEY, monthlyLimit REAL DEFAULT 0,
      yearlyLimit REAL DEFAULT 0, notifyAt REAL DEFAULT 0.8
    )''');
  }

  // ── Transactions ──────────────────────────────────────────
  static Future<void> upsertTransaction(TransactionModel tx) async {
    final d = await db;
    await d.insert('transactions', tx.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> deleteTransaction(String id) async {
    final d = await db;
    await d.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<TransactionModel>> fetchAllTransactions() async {
    final d = await db;
    final rows = await d.query('transactions', orderBy: 'date DESC, createdAt DESC');
    return rows.map(TransactionModel.fromMap).toList();
  }

  // ── Categories ────────────────────────────────────────────
  static Future<void> upsertCategory(CategoryModel cat) async {
    final d = await db;
    await d.insert('categories', cat.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> deleteCategory(String id) async {
    final d = await db;
    await d.delete('categories', where: 'id = ? AND isDefault = 0', whereArgs: [id]);
  }

  static Future<List<CategoryModel>> fetchAllCategories() async {
    final d = await db;
    final rows = await d.query('categories', orderBy: 'name ASC');
    return rows.map(CategoryModel.fromMap).toList();
  }

  static Future<int> countTransactionsByCategory(String categoryId) async {
    final d = await db;
    final result = await d.rawQuery(
        'SELECT COUNT(*) as c FROM transactions WHERE categoryId = ?', [categoryId]);
    return (result.first['c'] as int?) ?? 0;
  }

  // ── Budget ────────────────────────────────────────────────
  static Future<BudgetRecord> fetchBudget() async {
    final d = await db;
    final rows = await d.query('budgets', where: "id = 'main'");
    if (rows.isEmpty) return const BudgetRecord();
    final r = rows.first;
    return BudgetRecord(
      monthlyLimit: (r['monthlyLimit'] as num).toDouble(),
      yearlyLimit: (r['yearlyLimit'] as num).toDouble(),
      notifyAt: (r['notifyAt'] as num).toDouble(),
    );
  }

  static Future<void> saveBudget(BudgetRecord b) async {
    final d = await db;
    await d.insert('budgets', {
      'id': 'main',
      'monthlyLimit': b.monthlyLimit,
      'yearlyLimit': b.yearlyLimit,
      'notifyAt': b.notifyAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ── Wipe ──────────────────────────────────────────────────
  static Future<void> wipeAllLocalData() async {
    final d = await db;
    await d.delete('transactions');
    await d.delete('categories');
    await d.delete('budgets');
  }
}