// lib/screens/add_transaction_view.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../context/store.dart';
import '../utils/database.dart';
import '../utils/localization.dart';

class AddTransactionView extends StatefulWidget {
  final TransactionModel? editTx;
  const AddTransactionView({super.key, this.editTx});

  @override
  State<AddTransactionView> createState() => _AddTransactionViewState();
}

class _AddTransactionViewState extends State<AddTransactionView> {
  String _type = 'outcome';
  final _amountCtrl = TextEditingController();
  final _noteCtrl   = TextEditingController();
  CategoryModel? _selCat;
  DateTime _date = DateTime.now();
  String? _attachmentB64;
  String _error  = '';
  bool _saving   = false;

  @override
  void initState() {
    super.initState();
    final tx = widget.editTx;
    if (tx != null) {
      _type            = tx.type;
      _amountCtrl.text = tx.amount.toStringAsFixed(
          tx.amount == tx.amount.truncateToDouble() ? 0 : 2);
      _noteCtrl.text   = tx.note;
      _date            = DateTime.tryParse(tx.date) ?? DateTime.now();
      _attachmentB64   = tx.attachmentBase64;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.editTx != null && _selCat == null) {
      final cats = context.read<CategoryProvider>().categories;
      try {
        _selCat = cats.firstWhere((c) => c.id == widget.editTx!.categoryId);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // FIX: was `setState(() async => ...)` — async inside setState is silently
  // dropped and the assignment never ran. Extracted to a proper async method.
  Future<void> _pickImage(ImageSource src) async {
    final file = await ImagePicker().pickImage(
        source: src, maxWidth: 1024, maxHeight: 1024, imageQuality: 72);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) {
      setState(() => _attachmentB64 = base64Encode(bytes));
    }
  }

  void _showReceiptPicker(LocalizationProvider loc) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.camera_alt),
          title: Text(loc.str('camera')),
          onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
        ),
        ListTile(
          leading: const Icon(Icons.photo_library),
          title: Text(loc.str('photoLibrary')),
          onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
        ),
        ListTile(
          leading: const Icon(Icons.cancel),
          title: Text(loc.str('cancel')),
          onTap: () => Navigator.pop(context),
        ),
      ]),
    );
  }

  Future<void> _handleSave(LocalizationProvider loc) async {
    // FIX: use tryParse and guard against negative; also trim whitespace first
    final raw    = _amountCtrl.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(raw) ?? 0;
    if (amount <= 0) {
      setState(() => _error = loc.str('errAmount'));
      return;
    }
    if (_selCat == null) {
      setState(() => _error = loc.str('errCategory'));
      return;
    }

    setState(() { _error = ''; _saving = true; });
    try {
      final now     = DateTime.now().toIso8601String();
      final txStore = context.read<TransactionProvider>();
      final uid     = context.read<AuthProvider>().user?.uid;

      if (widget.editTx != null) {
        await txStore.update(
          widget.editTx!.copyWith(
            type:             _type,
            amount:           amount,
            categoryId:       _selCat!.id,
            categoryName:     _selCat!.name,
            note:             _noteCtrl.text.trim(),
            date:             _date.toIso8601String(),
            attachmentBase64: _attachmentB64,
            synced:           false,
            updatedAt:        now,
          ),
          uid: uid,
        );
      } else {
        await txStore.add(
          TransactionModel(
            id:               genId(),
            type:             _type,
            amount:           amount,
            categoryId:       _selCat!.id,
            categoryName:     _selCat!.name,
            note:             _noteCtrl.text.trim(),
            date:             _date.toIso8601String(),
            attachmentBase64: _attachmentB64,
            walletId:         'default',
            synced:           false,
            createdAt:        now,
            updatedAt:        now,
          ),
          uid: uid,
        );
      }

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc  = context.watch<LocalizationProvider>();
    final cats = context.watch<CategoryProvider>().categories;

    // FIX: filter by current type; also clear _selCat when type changes
    // so an income category isn't silently left selected for an expense.
    final filtered = cats
        .where((c) => c.type == _type || c.type == 'both')
        .toList();

    // Currency symbol from provider — not hardcoded to ₫
    final currencyCode = context.watch<CurrencyProvider>().code;
    final currencySymbol = _symbolFor(currencyCode);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.str('cancel'),
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
        title: Text(
          widget.editTx != null
              ? loc.str('editTransaction')
              : loc.str('addTransaction'),
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
        ),
        actions: [
          _saving
              ? const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primaryPurple),
            ),
          )
              : TextButton(
            onPressed: () => _handleSave(loc),
            child: Text(loc.str('save'),
                style: const TextStyle(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          // ── Type toggle ────────────────────────────────────────
          _Section(child: Container(
            decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(AppRadius.chip)),
            child: Row(children: [
              _SegBtn(
                label: loc.str('expense'),
                active: _type == 'outcome',
                onTap: () => setState(() {
                  _type = 'outcome';
                  // FIX: clear selected category when type switches so a
                  // category that doesn't belong to the new type isn't kept.
                  if (_selCat != null &&
                      _selCat!.type != 'outcome' &&
                      _selCat!.type != 'both') {
                    _selCat = null;
                  }
                }),
              ),
              _SegBtn(
                label: loc.str('income'),
                active: _type == 'income',
                onTap: () => setState(() {
                  _type = 'income';
                  if (_selCat != null &&
                      _selCat!.type != 'income' &&
                      _selCat!.type != 'both') {
                    _selCat = null;
                  }
                }),
              ),
            ]),
          )),

          // ── Amount ────────────────────────────────────────────
          _Section(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Label(loc.str('amount')),
              Row(children: [
                Text(currencySymbol,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _type == 'income'
                          ? AppColors.incomeGreen
                          : AppColors.outcomeRed,
                    )),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: '0',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: AppColors.textMuted),
                  ),
                )),
              ]),
            ],
          )),

          // ── Category chips ────────────────────────────────────
          _Section(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Label(loc.str('category')),
              if (filtered.isEmpty)
                Text(loc.str('noCategories'),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 14))
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: filtered.map((cat) {
                    final sel   = _selCat?.id == cat.id;
                    final color = hexColor(cat.colorHex);
                    return GestureDetector(
                      onTap: () => setState(() => _selCat = cat),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius:
                          BorderRadius.circular(AppRadius.chip),
                          border: Border.all(
                              color: sel ? color : AppColors.border,
                              width: sel ? 2 : 1),
                        ),
                        child: Column(children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(iconData(cat.icon),
                                size: 18, color: color),
                          ),
                          const SizedBox(height: 4),
                          Text(cat.name,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ]),
                      ),
                    );
                  }).toList()),
                ),
            ],
          )),

          // ── Note ─────────────────────────────────────────────
          _Section(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Label(loc.str('note')),
              TextField(
                controller: _noteCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: loc.str('note'),
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  border: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(AppRadius.chip)),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ],
          )),

          // ── Date ──────────────────────────────────────────────
          _Section(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Label(loc.str('date')),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null && mounted) {
                    setState(() => _date = picked);
                  }
                },
                child: Row(children: [
                  const Icon(Icons.calendar_today,
                      size: 18, color: AppColors.primaryPurple),
                  const SizedBox(width: 8),
                  Text(
                    '${_date.day}/${_date.month}/${_date.year}',
                    style: const TextStyle(
                        fontSize: 15, color: AppColors.textPrimary),
                  ),
                ]),
              ),
            ],
          )),

          // ── Receipt ───────────────────────────────────────────
          _Section(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Label(loc.str('receipt')),
              if (_attachmentB64 != null) ...[
                Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      base64Decode(_attachmentB64!),
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () =>
                        setState(() => _attachmentB64 = null),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side:
                      const BorderSide(color: AppColors.error),
                    ),
                    child: Text(loc.str('removeReceipt')),
                  ),
                ]),
              ] else
                GestureDetector(
                  onTap: () => _showReceiptPicker(loc),
                  child: Row(children: [
                    const Icon(Icons.attach_file,
                        size: 20,
                        color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(loc.str('addReceiptPhoto'),
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15)),
                  ]),
                ),
            ],
          )),

          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(_error,
                  style: const TextStyle(
                      color: AppColors.error, fontSize: 14)),
            ),

          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  /// Returns a short currency symbol for the given ISO code.
  String _symbolFor(String code) {
    const map = {
      'VND': '₫', 'USD': '\$', 'EUR': '€', 'GBP': '£',
      'JPY': '¥', 'CNY': '¥', 'KRW': '₩', 'THB': '฿',
    };
    return map[code] ?? code;
  }
}

// ── Shared sub-widgets ────────────────────────────────────────

class _Section extends StatelessWidget {
  final Widget child;
  const _Section({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    decoration: const BoxDecoration(
      color: AppColors.white,
      border:
      Border(bottom: BorderSide(color: AppColors.divider)),
    ),
    child: child,
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
        style: const TextStyle(
            fontSize: 13, color: AppColors.textSecondary)),
  );
}

class _SegBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SegBtn(
      {required this.label,
        required this.active,
        required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primaryPurple
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
              color: active
                  ? AppColors.white
                  : AppColors.textSecondary,
              fontWeight: active
                  ? FontWeight.w600
                  : FontWeight.normal,
              fontSize: 15,
            )),
      ),
    ),
  );
}