// lib/screens/category_management_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../context/store.dart';
import '../utils/database.dart';
import '../utils/localization.dart';

class CategoryManagementView extends StatefulWidget {
  const CategoryManagementView({super.key});
  @override
  State<CategoryManagementView> createState() => _CategoryManagementViewState();
}

class _CategoryManagementViewState extends State<CategoryManagementView> {
  String _filter = 'all';

  Future<void> _handleDelete(BuildContext ctx, CategoryModel cat) async {
    final loc = ctx.read<LocalizationProvider>();
    if (cat.isDefault) {
      ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(loc.str('cannotDeleteDefault'))));
      return;
    }
    final count = await AppDatabase.countTransactionsByCategory(cat.id);
    if (!ctx.mounted) return;
    showDialog(context: ctx, builder: (_) => AlertDialog(
      title: Text(loc.str('confirmDelete')),
      content: Text('$count ${loc.str('affectedTx')}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.str('cancel'))),
        TextButton(
          onPressed: () { Navigator.pop(ctx); ctx.read<CategoryProvider>().remove(cat.id); },
          child: Text(loc.str('delete'), style: const TextStyle(color: AppColors.error)),
        ),
      ],
    ));
  }

  void _openForm(BuildContext ctx, {CategoryModel? editCat}) {
    Navigator.push(ctx, MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _CategoryForm(editCat: editCat),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final loc  = context.watch<LocalizationProvider>();
    final cats = context.watch<CategoryProvider>().categories;
    final shown = cats.where((c) =>
    _filter == 'all' || c.type == _filter || (_filter != 'both' && c.type == 'both')).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.str('cancel'), style: const TextStyle(color: AppColors.textSecondary)),
        ),
        title: Text(loc.str('categoryManagement'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primaryPurple),
            onPressed: () => _openForm(context),
          ),
        ],
      ),
      body: Column(children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: ['all','income','outcome'].map((f) => GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _filter == f ? AppColors.primaryPurple : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(color: _filter == f ? AppColors.primaryPurple : AppColors.border),
              ),
              child: Text(loc.str(f), style: TextStyle(
                  color: _filter == f ? AppColors.white : AppColors.textSecondary, fontSize: 13)),
            ),
          )).toList()),
        ),

        Expanded(child: ListView.separated(
          itemCount: shown.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
          itemBuilder: (ctx, i) {
            final cat = shown[i];
            final color = hexColor(cat.colorHex);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconData(cat.icon), size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cat.name, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
                  Text(cat.type, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ])),
                if (cat.isDefault) Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(loc.str('defaultBadge'),
                      style: const TextStyle(fontSize: 11, color: AppColors.primaryPurple)),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: AppColors.primaryPurple),
                  onPressed: () => _openForm(ctx, editCat: cat),
                ),
                if (!cat.isDefault) IconButton(
                  icon: const Icon(Icons.delete, size: 18, color: AppColors.error),
                  onPressed: () => _handleDelete(ctx, cat),
                ),
              ]),
            );
          },
        )),
      ]),
    );
  }
}

// ── Category Form ─────────────────────────────────────────────
class _CategoryForm extends StatefulWidget {
  final CategoryModel? editCat;
  const _CategoryForm({this.editCat});
  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  final _nameCtrl = TextEditingController();
  String _type  = 'outcome';
  String _icon  = kIconOptions.first;
  String _color = kColorOptions.first;

  @override
  void initState() {
    super.initState();
    final c = widget.editCat;
    if (c != null) {
      _nameCtrl.text = c.name;
      _type  = c.type;
      _icon  = c.icon;
      _color = c.colorHex;
    }
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _handleSave() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    final now = DateTime.now().toIso8601String();
    final cat = CategoryModel(
      id:        widget.editCat?.id ?? genId(),
      name:      _nameCtrl.text.trim(),
      type:      _type,
      icon:      _icon,
      colorHex:  _color,
      isDefault: widget.editCat?.isDefault ?? false,
      createdAt: widget.editCat?.createdAt ?? now,
    );
    final store = context.read<CategoryProvider>();
    widget.editCat != null ? await store.update(cat) : await store.add(cat);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final loc   = context.watch<LocalizationProvider>();
    final color = hexColor(_color);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.str('cancel'), style: const TextStyle(color: AppColors.textSecondary)),
        ),
        title: Text(widget.editCat != null ? loc.str('edit') : loc.str('newCategory'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        actions: [
          TextButton(
            onPressed: _handleSave,
            child: Text(loc.str('save'),
                style: const TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.w600, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(child: Column(children: [
        // Preview
        Container(
          padding: const EdgeInsets.all(24),
          color: AppColors.white,
          child: Column(children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(iconData(_icon), size: 28, color: color),
            ),
            const SizedBox(height: 8),
            Text(_nameCtrl.text.isEmpty ? loc.str('preview') : _nameCtrl.text,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ]),
        ),
        const Divider(height: 1),

        // Name input
        _FormSection(label: loc.str('categoryName'), child: TextField(
          controller: _nameCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: loc.str('categoryName'),
            hintStyle: const TextStyle(color: AppColors.textMuted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
            contentPadding: const EdgeInsets.all(10),
          ),
        )),

        // Type
        _FormSection(label: loc.str('categoryType'), child: Container(
          decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(AppRadius.chip)),
          child: Row(children: ['outcome','income','both'].map((t) => Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _type = t),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _type == t ? AppColors.primaryPurple : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                alignment: Alignment.center,
                child: Text(
                  t == 'outcome' ? loc.str('expense') : t == 'income' ? loc.str('income') : loc.str('both'),
                  style: TextStyle(
                    color: _type == t ? AppColors.white : AppColors.textSecondary,
                    fontWeight: _type == t ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          )).toList()),
        )),

        // Icons
        _FormSection(label: loc.str('iconPicker'), child: Wrap(spacing: 8, runSpacing: 8,
          children: kIconOptions.map((ic) {
            final sel = _icon == ic;
            return GestureDetector(
              onTap: () => setState(() => _icon = ic),
              child: Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: sel ? color.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel ? color : AppColors.border,
                    width: sel ? 2 : 1,
                  ),
                ),
                child: Icon(iconData(ic), size: 22, color: sel ? color : AppColors.textSecondary),
              ),
            );
          }).toList(),
        )),

        // Colors
        _FormSection(label: loc.str('colorPicker'), child: Wrap(spacing: 10, runSpacing: 10,
          children: kColorOptions.map((c) {
            final sel = _color == c;
            return GestureDetector(
              onTap: () => setState(() => _color = c),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: hexColor(c),
                  shape: BoxShape.circle,
                  border: sel ? Border.all(color: AppColors.textPrimary, width: 3) : null,
                ),
              ),
            );
          }).toList(),
        )),

        const SizedBox(height: 40),
      ])),
    );
  }
}

class _FormSection extends StatelessWidget {
  final String label;
  final Widget child;
  const _FormSection({required this.label, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    decoration: const BoxDecoration(
      color: AppColors.white,
      border: Border(bottom: BorderSide(color: AppColors.divider)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      child,
    ]),
  );
}