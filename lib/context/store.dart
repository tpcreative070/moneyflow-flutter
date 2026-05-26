// lib/context/store.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../utils/database.dart';
import '../constants/theme.dart';

const _uuid = Uuid();
String genId() => _uuid.v4();

// ─── Auth ─────────────────────────────────────────────────────
class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String? photoURL;
  const UserModel({required this.uid, required this.displayName, required this.email, this.photoURL});
}

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isGuest = false;
  bool _loading = false;

  UserModel? get user => _user;
  bool get isGuest => _isGuest;
  bool get loading => _loading;

  void setUser(UserModel u) { _user = u; _isGuest = false; _loading = false; notifyListeners(); }
  void setGuest() {
    _user = const UserModel(uid: 'guest_demo', displayName: 'Guest', email: '');
    _isGuest = true; _loading = false; notifyListeners();
  }
  void setLoading(bool v) { _loading = v; notifyListeners(); }

  Future<void> signOut() async {
    await AppDatabase.wipeAllLocalData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tx_pending_upload');
    await prefs.remove('tx_pending_delete');
    await prefs.remove('app_currency');
    _user = null; _isGuest = false; _loading = false;
    notifyListeners();
  }
}

// ─── Currency ─────────────────────────────────────────────────
class CurrencyProvider extends ChangeNotifier {
  String _code = 'VND';
  String get code => _code;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString('app_currency');
    if (v != null) { _code = v; notifyListeners(); }
  }

  Future<void> setCode(String code) async {
    _code = code; notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_currency', code);
  }
}

// ─── Network ──────────────────────────────────────────────────
class NetworkProvider extends ChangeNotifier {
  bool _isConnected = true;
  bool get isConnected => _isConnected;

  void setConnected(bool v) { _isConnected = v; notifyListeners(); }
}

// ─── Transactions ─────────────────────────────────────────────
class TransactionProvider extends ChangeNotifier {
  List<TransactionModel> _transactions = [];
  Set<String> _pendingUpload = {};
  Set<String> _pendingDelete = {};
  bool _syncing = false;

  List<TransactionModel> get transactions => _transactions;
  Set<String> get pendingUpload => _pendingUpload;
  bool get syncing => _syncing;

  Future<void> load() async {
    final txs = await AppDatabase.fetchAllTransactions();
    final prefs = await SharedPreferences.getInstance();
    final pu = prefs.getStringList('tx_pending_upload') ?? [];
    final pd = prefs.getStringList('tx_pending_delete') ?? [];
    _transactions = txs;
    _pendingUpload = Set.from(pu);
    _pendingDelete = Set.from(pd);
    notifyListeners();
  }

  Future<void> add(TransactionModel tx) async {
    final local = tx.copyWith(synced: false);
    await AppDatabase.upsertTransaction(local);
    _pendingUpload.add(tx.id);
    _transactions.insert(0, local);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tx_pending_upload', _pendingUpload.toList());
    notifyListeners();
  }

  Future<void> update(TransactionModel tx) async {
    final local = tx.copyWith(synced: false);
    await AppDatabase.upsertTransaction(local);
    _pendingUpload.add(tx.id);
    _transactions = _transactions.map((t) => t.id == tx.id ? local : t).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tx_pending_upload', _pendingUpload.toList());
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await AppDatabase.deleteTransaction(id);
    _pendingDelete.add(id);
    _pendingUpload.remove(id);
    _transactions = _transactions.where((t) => t.id != id).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tx_pending_delete', _pendingDelete.toList());
    await prefs.setStringList('tx_pending_upload', _pendingUpload.toList());
    notifyListeners();
  }

  Future<void> syncPending() async {
    if (_syncing) return;
    _syncing = true;
    notifyListeners();
    try {
      // Stub: in production replace with your Firestore/REST calls
      // For now just mark everything as synced locally
      final uploadIds = List<String>.from(_pendingUpload);
      for (final id in uploadIds) {
        final tx = _transactions.firstWhere(
              (t) => t.id == id,
          orElse: () => TransactionModel(
              id: '', amount: 0, date: '', categoryId: '',
              categoryName: '', type: '', createdAt: '', updatedAt: ''),
        );
        if (tx.id.isEmpty) { _pendingUpload.remove(id); continue; }
        try {
          // await uploadTransaction(tx); // ← wire your Firestore call here
          final synced = tx.copyWith(synced: true);
          await AppDatabase.upsertTransaction(synced);
          _transactions = _transactions.map((t) => t.id == id ? synced : t).toList();
          _pendingUpload.remove(id);
        } catch (_) { /* leave in pending */ }
      }

      final deleteIds = List<String>.from(_pendingDelete);
      for (final id in deleteIds) {
        try {
          // await removeTransaction(id); // ← wire your Firestore call here
          _pendingDelete.remove(id);
        } catch (_) {}
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('tx_pending_upload', _pendingUpload.toList());
      await prefs.setStringList('tx_pending_delete', _pendingDelete.toList());
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }
}

// ─── Categories ───────────────────────────────────────────────
class CategoryProvider extends ChangeNotifier {
  List<CategoryModel> _categories = [];
  List<CategoryModel> get categories => _categories;

  Future<void> load() async {
    var cats = await AppDatabase.fetchAllCategories();
    if (cats.isEmpty) {
      for (final c in kDefaultCategories) await AppDatabase.upsertCategory(c);
      cats = await AppDatabase.fetchAllCategories();
    }
    _categories = cats;
    notifyListeners();
  }

  Future<void> add(CategoryModel cat) async {
    await AppDatabase.upsertCategory(cat);
    _categories = [..._categories, cat];
    notifyListeners();
  }

  Future<void> update(CategoryModel cat) async {
    await AppDatabase.upsertCategory(cat);
    _categories = _categories.map((c) => c.id == cat.id ? cat : c).toList();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await AppDatabase.deleteCategory(id);
    _categories = _categories.where((c) => c.id != id).toList();
    notifyListeners();
  }
}

// ─── Budget ───────────────────────────────────────────────────
class BudgetProvider extends ChangeNotifier {
  BudgetRecord _budget = const BudgetRecord();
  BudgetRecord get budget => _budget;

  Future<void> load() async {
    _budget = await AppDatabase.fetchBudget();
    notifyListeners();
  }

  Future<void> save(BudgetRecord b) async {
    await AppDatabase.saveBudget(b);
    _budget = b;
    notifyListeners();
  }
}