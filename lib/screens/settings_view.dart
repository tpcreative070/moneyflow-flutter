// lib/screens/settings_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../context/store.dart';
import '../utils/localization.dart';
import 'category_management_view.dart';

const _appVersion = '1.0.0';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _monthlyCtrl = TextEditingController();
  final _yearlyCtrl  = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final b = context.read<BudgetProvider>().budget;
      _monthlyCtrl.text = b.monthlyLimit > 0 ? b.monthlyLimit.toStringAsFixed(0) : '';
      _yearlyCtrl.text  = b.yearlyLimit  > 0 ? b.yearlyLimit.toStringAsFixed(0)  : '';
    });
  }

  @override
  void dispose() { _monthlyCtrl.dispose(); _yearlyCtrl.dispose(); super.dispose(); }

  void _flush(BudgetProvider store) {
    store.save(store.budget.copyWith(
      monthlyLimit: double.tryParse(_monthlyCtrl.text) ?? 0,
      yearlyLimit:  double.tryParse(_yearlyCtrl.text)  ?? 0,
    ));
  }

  Color _budgetColor(double progress, double notifyAt) {
    if (progress >= 1)        return AppColors.error;
    if (progress >= notifyAt) return AppColors.warningOrange;
    return AppColors.incomeGreen;
  }

  void _handleSignOut(BuildContext ctx) {
    final loc   = ctx.read<LocalizationProvider>();
    final auth  = ctx.read<AuthProvider>();
    showDialog(context: ctx, builder: (_) => AlertDialog(
      title: Text(loc.str('signOutConfirm')),
      content: Text(loc.str('signOutWarn')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.str('cancel'))),
        TextButton(
          onPressed: () { Navigator.pop(ctx); auth.signOut(); },
          child: Text(auth.isGuest ? loc.str('exitGuestMode') : loc.str('signOut'),
              style: const TextStyle(color: AppColors.error)),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final loc      = context.watch<LocalizationProvider>();
    final auth     = context.watch<AuthProvider>();
    final currency = context.watch<CurrencyProvider>();
    final budget   = context.watch<BudgetProvider>();
    final cats     = context.watch<CategoryProvider>();
    final txStore  = context.watch<TransactionProvider>();

    final now = DateTime.now();
    final monthSpend = txStore.transactions
        .where((t) => t.type == 'outcome' && DateTime.parse(t.date).month == now.month
        && DateTime.parse(t.date).year == now.year)
        .fold(0.0, (s, t) => s + t.amount);
    final yearSpend = txStore.transactions
        .where((t) => t.type == 'outcome' && DateTime.parse(t.date).year == now.year)
        .fold(0.0, (s, t) => s + t.amount);

    final mProgress = budget.budget.monthlyLimit > 0
        ? (monthSpend / budget.budget.monthlyLimit).clamp(0.0, 1.0) : 0.0;
    final yProgress = budget.budget.yearlyLimit > 0
        ? (yearSpend / budget.budget.yearlyLimit).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(children: [
            const SizedBox(height: 16),

            // Profile card
            _Card(child: Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryPurple, width: 2),
                ),
                child: const Icon(Icons.person, size: 32, color: AppColors.primaryPurple),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(auth.user?.displayName ?? loc.str('guestMode'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                if (auth.user?.email != null && auth.user!.email.isNotEmpty)
                  Text(auth.user!.email,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ]),
            ])),

            // Language
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _CardLabel(loc.str('language')),
              Container(
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(AppRadius.chip)),
                child: Row(children: [
                  _SegBtn(label: 'Tiếng Việt', active: loc.language == 'vi', onTap: () => loc.setLanguage('vi')),
                  _SegBtn(label: 'English', active: loc.language == 'en', onTap: () => loc.setLanguage('en')),
                ]),
              ),
            ])),

            // Currency
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _CardLabel(loc.str('currency')),
              Wrap(spacing: 8, runSpacing: 8, children: kCurrencies.map((c) {
                final sel = currency.code == c.code;
                return GestureDetector(
                  onTap: () => currency.setCode(c.code),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primaryPurple.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                      border: Border.all(color: sel ? AppColors.primaryPurple : AppColors.border),
                    ),
                    child: Column(children: [
                      Text(c.flag, style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 2),
                      Text(c.code, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Text(c.symbol, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ]),
                  ),
                );
              }).toList()),
            ])),

            // Budget
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _CardLabel(loc.str('budget')),

              Text(loc.str('monthlyLimit'), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _monthlyCtrl,
                keyboardType: TextInputType.number,
                onEditingComplete: () => _flush(budget),
                onSubmitted: (_) => _flush(budget),
                decoration: InputDecoration(
                  hintText: loc.str('noLimit'),
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
              if (budget.budget.monthlyLimit > 0) ...[
                const SizedBox(height: 8),
                _ProgressBar(progress: mProgress, color: _budgetColor(mProgress, budget.budget.notifyAt)),
                if (mProgress >= budget.budget.notifyAt)
                  _WarnRow(
                    exceeded: mProgress >= 1,
                    label: mProgress >= 1 ? loc.str('budgetExceeded') : loc.str('budgetWarning'),
                    progress: mProgress,
                  ),
              ],

              const SizedBox(height: 14),
              Text(loc.str('yearlyLimit'), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _yearlyCtrl,
                keyboardType: TextInputType.number,
                onEditingComplete: () => _flush(budget),
                onSubmitted: (_) => _flush(budget),
                decoration: InputDecoration(
                  hintText: loc.str('noLimit'),
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
              if (budget.budget.yearlyLimit > 0) ...[
                const SizedBox(height: 8),
                _ProgressBar(progress: yProgress, color: _budgetColor(yProgress, budget.budget.notifyAt)),
              ],
            ])),

            // Categories nav
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryManagementView())),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
                ),
                child: Row(children: [
                  const Icon(Icons.category, size: 22, color: AppColors.primaryPurple),
                  const SizedBox(width: 12),
                  Expanded(child: Text(loc.str('categories'),
                      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text('${cats.categories.length}',
                        style: const TextStyle(fontSize: 12, color: AppColors.primaryPurple, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
                ]),
              ),
            ),

            // App info
            _Card(child: Column(children: [
              _CardLabel(loc.str('appInfo')),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(loc.str('version'), style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                Text(_appVersion, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
              ]),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(loc.str('cloudSync'), style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                txStore.pendingUpload.isEmpty
                    ? Row(children: [
                  const Icon(Icons.check_circle, size: 15, color: AppColors.incomeGreen),
                  const SizedBox(width: 4),
                  Text(loc.str('allSynced'), style: const TextStyle(fontSize: 14, color: AppColors.incomeGreen)),
                ])
                    : Row(children: [
                  const Icon(Icons.sync, size: 15, color: AppColors.warningOrange),
                  const SizedBox(width: 4),
                  Text('${txStore.pendingUpload.length} ${loc.str('pendingSync')}',
                      style: const TextStyle(fontSize: 14, color: AppColors.warningOrange)),
                ]),
              ]),
            ])),

            // Sign out
            GestureDetector(
              onTap: () => _handleSignOut(context),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.logout, size: 20, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text(auth.isGuest ? loc.str('exitGuestMode') : loc.str('signOut'),
                      style: const TextStyle(color: AppColors.error, fontSize: 15, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.card),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
    ),
    child: child,
  );
}

class _CardLabel extends StatelessWidget {
  final String text;
  const _CardLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(text.toUpperCase(),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: AppColors.textSecondary, letterSpacing: 0.5)),
  );
}

class _SegBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SegBtn({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(
            color: active ? AppColors.white : AppColors.textSecondary,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal, fontSize: 14)),
      ),
    ),
  );
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  final Color color;
  const _ProgressBar({required this.progress, required this.color});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: LinearProgressIndicator(
      value: progress,
      minHeight: 6,
      backgroundColor: AppColors.divider,
      valueColor: AlwaysStoppedAnimation<Color>(color),
    ),
  );
}

class _WarnRow extends StatelessWidget {
  final bool exceeded;
  final String label;
  final double progress;
  const _WarnRow({required this.exceeded, required this.label, required this.progress});
  @override
  Widget build(BuildContext context) {
    final color = exceeded ? AppColors.error : AppColors.warningOrange;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(children: [
        Icon(exceeded ? Icons.error : Icons.warning, size: 15, color: color),
        const SizedBox(width: 6),
        Text('$label — ${(progress * 100).round()}%',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
      ]),
    );
  }
}