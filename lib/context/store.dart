// lib/context/store.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../utils/database.dart';
import '../constants/theme.dart';

const _uuid = Uuid();
String genId() => _uuid.v4();

// ─── Firestore helpers ────────────────────────────────────────
// All transactions live under:  users/{uid}/transactions/{txId}
FirebaseFirestore get _fs => FirebaseFirestore.instance;

CollectionReference<Map<String, dynamic>> _txCol(String uid) =>
    _fs.collection('users').doc(uid).collection('transactions');

// ─── Auth ─────────────────────────────────────────────────────
class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String? photoURL;
  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoURL,
  });
}

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isGuest   = false;
  bool _loading   = false;
  bool _isLoading = true;

  UserModel? get user    => _user;
  bool get isGuest       => _isGuest;
  bool get loading       => _loading;
  bool get isLoading     => _isLoading;

  AuthProvider() {
    // FIX: safety net — if Firebase.initializeApp() timed out or failed,
    // authStateChanges() will never emit an event, leaving _isLoading = true
    // forever and the app stuck on the branded splash screen.
    // After 6 seconds with no auth event, force _isLoading = false so the
    // user reaches the AuthScreen and can proceed as a guest.
    Future.delayed(const Duration(seconds: 6), () {
      if (_isLoading) {
        debugPrint('[AuthProvider] auth state timeout — forcing isLoading=false');
        _isLoading = false;
        notifyListeners();
      }
    });

    fb.FirebaseAuth.instance.authStateChanges().listen((firebaseUser) {
      if (!_isGuest) {
        _user = firebaseUser == null
            ? null
            : UserModel(
          uid:         firebaseUser.uid,
          displayName: firebaseUser.displayName ?? 'User',
          email:       firebaseUser.email ?? '',
          photoURL:    firebaseUser.photoURL,
        );
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  void setUser(UserModel u) {
    _user = u; _isGuest = false; _loading = false;
    notifyListeners();
  }

  void setGuest() {
    _user = const UserModel(uid: 'guest_demo', displayName: 'Guest', email: '');
    _isGuest = true; _loading = false; _isLoading = false;
    notifyListeners();
  }

  void setLoading(bool v) { _loading = v; notifyListeners(); }

  Future<void> signOut() async {
    await AppDatabase.wipeAllLocalData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tx_pending_upload');
    await prefs.remove('tx_pending_delete');
    await prefs.remove('app_currency');
    _isGuest = false; _loading = false;
    await fb.FirebaseAuth.instance.signOut();
    if (_isGuest) { _user = null; notifyListeners(); }
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

// ─── Date Filter ──────────────────────────────────────────────
enum DateFilter { today, thisWeek, thisMonth, thisYear, all }

// ─── Transactions ─────────────────────────────────────────────
class TransactionProvider extends ChangeNotifier {
  List<TransactionModel> _transactions         = [];
  List<TransactionModel> _filteredTransactions = [];
  Set<String>            _pendingUpload        = {};
  Set<String>            _pendingDelete        = {};
  bool                   _syncing              = false;
  bool                   _isLoading            = false;

  // ── Filter state ─────────────────────────────────────────────
  String      _searchText        = '';
  DateFilter  _selectedDateFilter = DateFilter.thisMonth;
  DateTime?   _customDateFrom;
  DateTime?   _customDateTo;
  String?     _selectedType;         // 'income' | 'outcome' | null
  String?     _selectedCategoryId;
  bool        _sortNewestFirst    = true;

  // ── Getters ──────────────────────────────────────────────────
  List<TransactionModel> get transactions         => _transactions;
  List<TransactionModel> get filteredTransactions => _filteredTransactions;
  Set<String>            get pendingUpload        => _pendingUpload;
  bool                   get syncing              => _syncing;
  bool                   get isLoading            => _isLoading;

  String      get searchText          => _searchText;
  DateFilter  get selectedDateFilter  => _selectedDateFilter;
  DateTime?   get customDateFrom      => _customDateFrom;
  DateTime?   get customDateTo        => _customDateTo;
  String?     get selectedType        => _selectedType;
  String?     get selectedCategoryId  => _selectedCategoryId;
  bool        get sortNewestFirst     => _sortNewestFirst;

  bool get hasCustomRange => _customDateFrom != null || _customDateTo != null;

  /// Count of active non-default filters (mirrors Swift's activeFilterCount).
  int get activeFilterCount {
    int count = 0;
    if (hasCustomRange)              count++;
    if (_selectedType != null)       count++;
    if (_selectedCategoryId != null) count++;
    return count;
  }

  // ── Computed totals on the *filtered* list ───────────────────
  double get totalIncome  => _filteredTransactions
      .where((t) => t.type == 'income')
      .fold(0.0, (s, t) => s + t.amount);

  double get totalOutcome => _filteredTransactions
      .where((t) => t.type == 'outcome')
      .fold(0.0, (s, t) => s + t.amount);

  double get balance => totalIncome - totalOutcome;

  // ── Filter setters — each triggers applyFilters() ────────────
  void setSearchText(String v) {
    _searchText = v;
    applyFilters();
    notifyListeners();
  }

  void setDateFilter(DateFilter f) {
    _selectedDateFilter = f;
    _customDateFrom = null;
    _customDateTo   = null;
    applyFilters();
    notifyListeners();
  }

  void setCustomDateFrom(DateTime? d) {
    _customDateFrom = d;
    applyFilters();
    notifyListeners();
  }

  void setCustomDateTo(DateTime? d) {
    _customDateTo = d;
    applyFilters();
    notifyListeners();
  }

  void setSelectedType(String? type) {
    _selectedType = type;
    applyFilters();
    notifyListeners();
  }

  void setSelectedCategoryId(String? id) {
    _selectedCategoryId = id;
    applyFilters();
    notifyListeners();
  }

  void setSortNewestFirst(bool v) {
    _sortNewestFirst = v;
    applyFilters();
    notifyListeners();
  }

  void clearCustomRange() {
    _customDateFrom = null;
    _customDateTo   = null;
    applyFilters();
    notifyListeners();
  }

  /// Reset every filter back to defaults.
  void resetAllFilters() {
    _searchText          = '';
    _selectedDateFilter  = DateFilter.thisMonth;
    _customDateFrom      = null;
    _customDateTo        = null;
    _selectedType        = null;
    _selectedCategoryId  = null;
    _sortNewestFirst     = true;
    applyFilters();
    notifyListeners();
  }

  // ── Filter engine ─────────────────────────────────────────────
  void applyFilters() {
    var result = List<TransactionModel>.from(_transactions);
    final now = DateTime.now();

    // 1. Date
    if (hasCustomRange) {
      if (_customDateFrom != null) {
        final from = DateTime(
            _customDateFrom!.year, _customDateFrom!.month, _customDateFrom!.day);
        result = result.where((t) {
          final d = DateTime.tryParse(t.date);
          return d != null && !d.isBefore(from);
        }).toList();
      }
      if (_customDateTo != null) {
        final to = DateTime(_customDateTo!.year, _customDateTo!.month,
            _customDateTo!.day, 23, 59, 59);
        result = result.where((t) {
          final d = DateTime.tryParse(t.date);
          return d != null && !d.isAfter(to);
        }).toList();
      }
    } else {
      DateTime? start;
      switch (_selectedDateFilter) {
        case DateFilter.today:
          start = DateTime(now.year, now.month, now.day);
        case DateFilter.thisWeek:
        // Monday as week start
          final weekday = now.weekday; // 1=Mon … 7=Sun
          start = DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: weekday - 1));
        case DateFilter.thisMonth:
          start = DateTime(now.year, now.month, 1);
        case DateFilter.thisYear:
          start = DateTime(now.year, 1, 1);
        case DateFilter.all:
          start = null;
      }
      if (start != null) {
        result = result.where((t) {
          final d = DateTime.tryParse(t.date);
          return d != null && !d.isBefore(start!);
        }).toList();
      }
    }

    // 2. Type
    if (_selectedType != null) {
      result = result.where((t) => t.type == _selectedType).toList();
    }

    // 3. Category
    if (_selectedCategoryId != null) {
      result =
          result.where((t) => t.categoryId == _selectedCategoryId).toList();
    }

    // 4. Search
    final q = _searchText.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((t) {
        return t.note.toLowerCase().contains(q) ||
            t.categoryName.toLowerCase().contains(q);
      }).toList();
    }

    // 5. Sort
    result.sort((a, b) {
      final da = DateTime.tryParse(a.date) ?? DateTime(0);
      final db = DateTime.tryParse(b.date) ?? DateTime(0);
      return _sortNewestFirst ? db.compareTo(da) : da.compareTo(db);
    });

    _filteredTransactions = result;
  }

  // ── Wipe in-memory state on sign-out ─────────────────────────
  void clearInMemory() {
    _transactions         = [];
    _filteredTransactions = [];
    _pendingUpload        = {};
    _pendingDelete        = {};
    resetAllFilters(); // also calls notifyListeners()
  }

  // ── load from local SQLite ───────────────────────────────────
  Future<void> load() async {
    final txs   = await AppDatabase.fetchAllTransactions();
    final prefs = await SharedPreferences.getInstance();
    _transactions  = txs;
    _pendingUpload = Set.from(prefs.getStringList('tx_pending_upload') ?? []);
    _pendingDelete = Set.from(prefs.getStringList('tx_pending_delete') ?? []);
    applyFilters();
    notifyListeners();
  }

  // ── add ──────────────────────────────────────────────────────
  Future<void> add(TransactionModel tx, {String? uid}) async {
    final local = tx.copyWith(synced: false);
    await AppDatabase.upsertTransaction(local);
    _transactions.insert(0, local);
    _pendingUpload.add(tx.id);
    await _savePendingPrefs();
    applyFilters();
    notifyListeners();

    if (uid != null && uid != 'guest_demo') {
      await _uploadOne(local, uid);
    }
  }

  // ── update ───────────────────────────────────────────────────
  Future<void> update(TransactionModel tx, {String? uid}) async {
    final local = tx.copyWith(
      synced:    false,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await AppDatabase.upsertTransaction(local);
    _transactions = _transactions
        .map((t) => t.id == tx.id ? local : t)
        .toList();
    _pendingUpload.add(tx.id);
    await _savePendingPrefs();
    applyFilters();
    notifyListeners();

    if (uid != null && uid != 'guest_demo') {
      await _uploadOne(local, uid);
    }
  }

  // ── remove ───────────────────────────────────────────────────
  Future<void> remove(String id, {String? uid}) async {
    await AppDatabase.deleteTransaction(id);
    _pendingUpload.remove(id); // no point uploading something we're deleting
    _pendingDelete.add(id);
    _transactions = _transactions.where((t) => t.id != id).toList();
    await _savePendingPrefs();
    applyFilters();
    notifyListeners();

    if (uid != null && uid != 'guest_demo') {
      await _deleteOne(id, uid);
    }
  }

  // ── syncPending: flush queues when network comes back ────────
  Future<void> syncPending({required String uid}) async {
    if (_syncing || uid == 'guest_demo') return;
    _syncing = true;
    notifyListeners();

    debugPrint('┌─────────────────────────────────────────');
    debugPrint('│ [Firestore] SYNC PENDING START');
    debugPrint('│   pendingUpload=${_pendingUpload.length}  pendingDelete=${_pendingDelete.length}');

    final stopwatch = Stopwatch()..start();

    try {
      // Upload anything explicitly queued OR still marked unsynced
      final toUpload = _transactions
          .where((t) => !t.synced || _pendingUpload.contains(t.id))
          .toList();
      if (toUpload.isNotEmpty) {
        debugPrint('│ [Firestore] Uploading ${toUpload.length} unsynced transaction(s)…');
        for (final tx in toUpload) {
          await _uploadOne(tx, uid);
        }
        _pendingUpload.clear();
      } else {
        debugPrint('│ [Firestore] Nothing to upload');
      }

      // Remote deletes
      final toDelete = List<String>.from(_pendingDelete);
      if (toDelete.isNotEmpty) {
        debugPrint('│ [Firestore] Deleting ${toDelete.length} transaction(s) from Firestore…');
        for (final id in toDelete) {
          await _deleteOne(id, uid);
        }
      } else {
        debugPrint('│ [Firestore] Nothing to delete');
      }

      await _savePendingPrefs();

      stopwatch.stop();
      debugPrint('│ [Firestore] SYNC PENDING DONE  (${stopwatch.elapsedMilliseconds}ms)  ✅');
      debugPrint('└─────────────────────────────────────────');
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  // ── pull from Firestore → merge into local ───────────────────
  Future<void> fetchFromFirestore(String uid) async {
    if (uid == 'guest_demo') return;
    _isLoading = true;
    notifyListeners();

    debugPrint('┌─────────────────────────────────────────');
    debugPrint('│ [Firestore] FETCH START  uid=$uid');
    debugPrint('│ [Firestore] Local cache: ${_transactions.length} transactions');

    final stopwatch = Stopwatch()..start();

    try {
      final snap = await _txCol(uid)
          .orderBy('updatedAt', descending: true)
          .get();

      debugPrint('│ [Firestore] Remote docs : ${snap.docs.length}');

      int newCount     = 0;
      int updatedCount = 0;
      int skippedCount = 0;
      bool didChange   = false;

      for (final doc in snap.docs) {
        final data = doc.data();

        final tx = TransactionModel(
          id:               doc.id,
          amount:           (data['amount'] as num).toDouble(),
          date:             data['date'] as String,
          note:             data['note'] as String? ?? '',
          categoryId:       data['categoryId'] as String,
          categoryName:     data['categoryName'] as String,
          type:             data['type'] as String,
          walletId:         data['walletId'] as String? ?? 'default',
          synced:           true,
          // Coerce empty string back to null.
          attachmentBase64: (data['attachmentBase64'] as String?)?.isEmpty == false
              ? data['attachmentBase64'] as String?
              : null,
          createdAt:        data['createdAt'] as String,
          updatedAt:        data['updatedAt'] as String,
        );

        final existingIndex =
        _transactions.indexWhere((t) => t.id == doc.id);

        if (existingIndex == -1) {
          // New record from Firestore — insert locally.
          await AppDatabase.upsertTransaction(tx);
          _transactions.add(tx);
          didChange = true;
          newCount++;
          debugPrint('│   ⬇ NEW      ${doc.id}  ${tx.categoryName}  ${tx.type}  ${tx.amount}  date=${tx.date}');
        } else {
          final local = _transactions[existingIndex];
          final remoteIsNewer = tx.updatedAt.compareTo(local.updatedAt) > 0;
          if (remoteIsNewer) {
            // Remote is newer — overwrite local copy.
            await AppDatabase.upsertTransaction(tx);
            _transactions[existingIndex] = tx;
            didChange = true;
            updatedCount++;
            debugPrint('│   ⬇ UPDATED  ${doc.id}  ${tx.categoryName}  localUpdatedAt=${local.updatedAt}  remoteUpdatedAt=${tx.updatedAt}');
          } else {
            skippedCount++;
            debugPrint('│   ✓ SKIP     ${doc.id}  already up-to-date');
          }
        }
      }

      if (didChange) {
        // Re-sort by date descending after merge.
        _transactions.sort((a, b) {
          final da = DateTime.tryParse(a.date) ?? DateTime(0);
          final db = DateTime.tryParse(b.date) ?? DateTime(0);
          return db.compareTo(da);
        });
        applyFilters();
      }

      _pendingUpload = {};
      _pendingDelete = {};
      await _savePendingPrefs();

      stopwatch.stop();
      debugPrint('│');
      debugPrint('│ [Firestore] FETCH DONE  (${stopwatch.elapsedMilliseconds}ms)');
      debugPrint('│   new=$newCount  updated=$updatedCount  skipped=$skippedCount');
      debugPrint('│   total local after merge: ${_transactions.length}');
      debugPrint('└─────────────────────────────────────────');
    } catch (e, stack) {
      stopwatch.stop();
      debugPrint('│ [Firestore] FETCH ERROR  (${stopwatch.elapsedMilliseconds}ms)');
      debugPrint('│   $e');
      debugPrint('│   $stack');
      debugPrint('└─────────────────────────────────────────');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── private helpers ──────────────────────────────────────────
  Future<void> _uploadOne(TransactionModel tx, String uid) async {
    debugPrint('┌─────────────────────────────────────────');
    debugPrint('│ [Firestore] SAVE  id=${tx.id}');
    debugPrint('│   type=${tx.type}  amount=${tx.amount}  category=${tx.categoryName}');
    debugPrint('│   date=${tx.date}  note="${tx.note}"');
    debugPrint('│   hasAttachment=${tx.attachmentBase64 != null}  updatedAt=${tx.updatedAt}');

    final stopwatch = Stopwatch()..start();
    try {
      final data = {
        'id':               tx.id,
        'amount':           tx.amount,
        'date':             tx.date,
        'note':             tx.note,
        'categoryId':       tx.categoryId,
        'categoryName':     tx.categoryName,
        'type':             tx.type,
        'walletId':         tx.walletId,
        'userId':           uid,
        // Always write the key so the field is present on pull;
        // empty string when no attachment.
        'attachmentBase64': tx.attachmentBase64 ?? '',
        'createdAt':        tx.createdAt,
        'updatedAt':        tx.updatedAt,
      };
      await _txCol(uid).doc(tx.id).set(data, SetOptions(merge: true));

      final synced = tx.copyWith(synced: true);
      await AppDatabase.upsertTransaction(synced);
      _transactions = _transactions
          .map((t) => t.id == tx.id ? synced : t)
          .toList();
      _pendingUpload.remove(tx.id);
      applyFilters();
      // FIX: notifyListeners() was missing here — the sync indicator in the
      // UI (the cloud icon on each transaction row) never updated after a
      // successful upload because the widget tree was never rebuilt.
      notifyListeners();

      stopwatch.stop();
      debugPrint('│ [Firestore] SAVE OK  (${stopwatch.elapsedMilliseconds}ms)  ✅');
      debugPrint('└─────────────────────────────────────────');
    } catch (e, stack) {
      stopwatch.stop();
      _pendingUpload.add(tx.id); // re-queue for retry
      debugPrint('│ [Firestore] SAVE ERROR  (${stopwatch.elapsedMilliseconds}ms)  ❌');
      debugPrint('│   $e');
      debugPrint('│   $stack');
      debugPrint('└─────────────────────────────────────────');
    }
  }

  Future<void> _deleteOne(String id, String uid) async {
    debugPrint('┌─────────────────────────────────────────');
    debugPrint('│ [Firestore] DELETE  id=$id');
    final stopwatch = Stopwatch()..start();
    try {
      await _txCol(uid).doc(id).delete();
      _pendingDelete.remove(id);
      stopwatch.stop();
      debugPrint('│ [Firestore] DELETE OK  (${stopwatch.elapsedMilliseconds}ms)  🗑');
      debugPrint('└─────────────────────────────────────────');
    } catch (e, stack) {
      stopwatch.stop();
      // keep in _pendingDelete — will retry on next syncPending
      debugPrint('│ [Firestore] DELETE ERROR  (${stopwatch.elapsedMilliseconds}ms)  ❌');
      debugPrint('│   $e');
      debugPrint('│   $stack');
      debugPrint('└─────────────────────────────────────────');
    }
  }

  Future<void> _savePendingPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tx_pending_upload', _pendingUpload.toList());
    await prefs.setStringList('tx_pending_delete', _pendingDelete.toList());
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