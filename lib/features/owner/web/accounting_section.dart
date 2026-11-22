import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_utils.dart';
import '../../../core/widgets/premium_widgets.dart';
import '../../../data/models.dart';
import '../../../data/repositories.dart';
import 'web_ui.dart';

class AccountingSection extends ConsumerStatefulWidget {
  const AccountingSection({super.key});

  @override
  ConsumerState<AccountingSection> createState() => _AccountingSectionState();
}

class _AccountingSectionState extends ConsumerState<AccountingSection> {
  DateTime _month = startOfMonth(DateTime.now());
  String _filter = 'الكل';
  String _query = '';

  Future<void> _refresh() async {
    ref.invalidate(ownerSnapshotProvider);
    ref.invalidate(ownerDashboardProvider);
    await ref.read(ownerDashboardProvider.future);
  }

  List<Invoice> _applyInvoices(List<Invoice> invoices) {
    final query = _query.trim();
    return invoices.where((invoice) {
      final matchesFilter = switch (_filter) {
        'غير مسددة' => !invoice.isPaid,
        'متأخرة' => invoice.isOverdue,
        'مسددة' => invoice.isPaid,
        _ => true,
      };
      final matchesQuery = query.isEmpty ||
          invoice.number.contains(query) ||
          (invoice.tenantName ?? '').contains(query) ||
          (invoice.apartmentLabel ?? '').contains(query);
      return matchesFilter && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ownerDashboardProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ErrorView(
          message: friendlyError(error),
          onRetry: () => ref.invalidate(ownerDashboardProvider),
        ),
      ),
      data: (data) {
        final country = ref.watch(ownerCountryProvider);
        final portfolio = Portfolio(
          data.snapshot.portfolio.compounds
              .where((compound) => compound.country == country)
              .toList(),
        );
        final monthInvoices = data.invoices
            .where((invoice) =>
                invoice.country == country &&
                isSameMonth(invoice.invoiceDate, _month))
            .toList();
        final monthExpenses = data.expenses
            .where((expense) =>
                expense.country == country &&
                isSameMonth(expense.date, _month))
            .toList();
        final billed =
            monthInvoices.fold<double>(0, (sum, invoice) => sum + invoice.totalAmount);
        final collected =
            monthInvoices.fold<double>(0, (sum, invoice) => sum + invoice.paidAmount);
        final outstanding = monthInvoices
            .fold<double>(0, (sum, invoice) => sum + invoice.remaining);
        final expenses =
            monthExpenses.fold<double>(0, (sum, expense) => sum + expense.amount);
        final overdue =
            monthInvoices.where((invoice) => invoice.isOverdue).length;
        final visible = _applyInvoices(monthInvoices);

        double sumOf(double Function(Invoice) selector) =>
            monthInvoices.fold<double>(0, (sum, invoice) => sum + selector(invoice));

        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              WebPageHeader(
                title: 'المحاسبة',
                subtitle:
                    'فواتير الإيجار والتحصيل والمصروفات وصافي الدخل لشهر ${webMonthName(_month)} · ${country.name(english: I18n.isEnglish)}',
                actions: [
                  _MonthNavigator(
                    month: _month,
                    onPrevious: () =>
                        setState(() => _month = addMonths(_month, -1)),
                    onNext: () => setState(() => _month = addMonths(_month, 1)),
                    onReset: () =>
                        setState(() => _month = startOfMonth(DateTime.now())),
                  ),
                  FilledButton.icon(
                    onPressed: () => _generateInvoices(portfolio),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('توليد فواتير الشهر'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              WebKpiGrid(
                children: [
                  WebKpiCard(
                    label: 'إجمالي المفوتر',
                    value: moneyText(billed),
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.info,
                    caption: '${monthInvoices.length} فاتورة',
                  ),
                  WebKpiCard(
                    label: 'المحصّل',
                    value: moneyText(collected),
                    icon: Icons.savings_rounded,
                    color: AppColors.occupied,
                    caption: billed == 0
                        ? 'لا فواتير'
                        : 'نسبة ${percent(billed == 0 ? 0 : collected / billed)}',
                  ),
                  WebKpiCard(
                    label: 'المتبقي',
                    value: moneyText(outstanding),
                    icon: Icons.hourglass_bottom_rounded,
                    color: AppColors.pending,
                    caption: '$overdue فاتورة متأخرة',
                  ),
                  WebKpiCard(
                    label: 'المصروفات',
                    value: moneyText(expenses),
                    icon: Icons.trending_down_rounded,
                    color: AppColors.danger,
                    caption: '${monthExpenses.length} عملية',
                  ),
                  WebKpiCard(
                    label: 'صافي الشهر',
                    value: moneyText(collected - expenses),
                    icon: Icons.account_balance_rounded,
                    color: collected - expenses >= 0
                        ? AppColors.gold
                        : AppColors.danger,
                    caption: 'المحصّل − المصروفات',
                  ),
                  WebKpiCard(
                    label: 'نسبة التحصيل',
                    value: percent(billed == 0 ? 0 : collected / billed),
                    icon: Icons.donut_large_rounded,
                    color: AppColors.reserved,
                    caption: 'من فواتير الشهر',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              WebColumns(
                firstFlex: 3,
                secondFlex: 2,
                first: WebPanel(
                  title: 'فواتير ${webMonthName(_month)}',
                  subtitle: '${visible.length} فاتورة مطابقة',
                  action: SizedBox(
                    width: 210,
                    child: TextField(
                      onChanged: (value) => setState(() => _query = value),
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: tr('بحث'),
                        prefixIcon: Icon(Icons.search_rounded, size: 18),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['الكل', 'غير مسددة', 'متأخرة', 'مسددة']
                            .map(
                              (filter) => WebToolbarChip(
                                label: filter,
                                selected: _filter == filter,
                                onTap: () => setState(() => _filter = filter),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      WebTable(
                        empty: const WebEmpty(
                          icon: Icons.receipt_long_rounded,
                          title: 'لا توجد فواتير لهذا الشهر',
                          message:
                              'استخدم زر «توليد فواتير الشهر» لإنشاء فواتير العقود النشطة تلقائياً.',
                        ),
                        columns: const [
                          WebTableColumn('الفاتورة', flex: 2),
                          WebTableColumn('المستأجر', flex: 2),
                          WebTableColumn('الوحدة', flex: 2),
                          WebTableColumn('الإجمالي', flex: 2, align: TextAlign.end),
                          WebTableColumn('المتبقي', flex: 2, align: TextAlign.end),
                          WebTableColumn('الحالة', flex: 2, align: TextAlign.center),
                          WebTableColumn('', flex: 1, align: TextAlign.center),
                        ],
                        rows: visible
                            .take(80)
                            .map(
                              (invoice) => [
                                _InvoiceCell(invoice: invoice),
                                Text(
                                  invoice.tenantName ?? '—',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 11,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  invoice.apartmentLabel ?? '—',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 10,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                Text(
                                  moneyText(invoice.totalAmount),
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  invoice.isPaid
                                      ? '0'
                                      : moneyText(invoice.remaining),
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: invoice.isOverdue
                                        ? AppColors.danger
                                        : AppColors.pending,
                                  ),
                                ),
                                WebPill(
                                  label: invoice.statusLabel,
                                  color: invoice.isPaid
                                      ? AppColors.occupied
                                      : invoice.isOverdue
                                          ? AppColors.danger
                                          : AppColors.pending,
                                ),
                                WebRowAction(
                                  icon: Icons.payments_rounded,
                                  tooltip: invoice.isPaid
                                      ? 'مسددة بالكامل'
                                      : 'تسجيل دفعة',
                                  color: AppColors.occupied,
                                  onTap: invoice.isPaid
                                      ? null
                                      : () => _recordPayment(invoice),
                                ),
                              ],
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
                second: WebPanel(
                  title: 'تفصيل الشهر',
                  subtitle: webMonthName(_month),
                  child: Column(
                    children: [
                      _BreakdownRow(
                        label: 'إيجار',
                        value: sumOf((invoice) => invoice.rentAmount),
                        color: AppColors.gold,
                      ),
                      const SizedBox(height: 8),
                      _BreakdownRow(
                        label: 'خدمات',
                        value: sumOf((invoice) => invoice.utilitiesAmount),
                        color: AppColors.info,
                      ),
                      const SizedBox(height: 8),
                      _BreakdownRow(
                        label: 'صيانة',
                        value: sumOf((invoice) => invoice.maintenanceAmount),
                        color: AppColors.pending,
                      ),
                      const SizedBox(height: 8),
                      _BreakdownRow(
                        label: 'رسوم أخرى',
                        value: sumOf((invoice) => invoice.otherCharges),
                        color: AppColors.textSecondary,
                      ),
                      const Divider(height: 26),
                      WebInfoTile(
                        label: 'إجمالي المفوتر',
                        value: moneyText(billed),
                        icon: Icons.receipt_long_rounded,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(height: 8),
                      WebInfoTile(
                        label: 'المحصّل',
                        value: moneyText(collected),
                        icon: Icons.savings_rounded,
                        color: AppColors.occupied,
                      ),
                      const SizedBox(height: 8),
                      WebInfoTile(
                        label: 'المصروفات',
                        value: moneyText(expenses),
                        icon: Icons.trending_down_rounded,
                        color: AppColors.danger,
                      ),
                      const SizedBox(height: 8),
                      WebInfoTile(
                        label: 'الصافي',
                        value: moneyText(collected - expenses),
                        icon: Icons.account_balance_rounded,
                        color: AppColors.gold,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: billed == 0 ? 0 : (collected / billed).clamp(0, 1),
                          minHeight: 9,
                          backgroundColor: Colors.white.withValues(alpha: .07),
                          valueColor:
                              const AlwaysStoppedAnimation(AppColors.occupied),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'نسبة التحصيل ${percent(billed == 0 ? 0 : collected / billed)}',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              WebPanel(
                title: 'المصروفات',
                subtitle: 'مصروفات شهر ${webMonthName(_month)}',
                action: TextButton.icon(
                  onPressed: () => _addExpense(portfolio),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('إضافة مصروف'),
                ),
                child: WebTable(
                  empty: const WebEmpty(
                    icon: Icons.money_off_rounded,
                    title: 'لا توجد مصروفات مسجلة لهذا الشهر',
                    message: 'أضف صيانة أو رواتب أو فواتير خدمات لتظهر في حساباتك.',
                  ),
                  columns: const [
                    WebTableColumn('التاريخ', flex: 2),
                    WebTableColumn('البيان', flex: 3),
                    WebTableColumn('التصنيف', flex: 2),
                    WebTableColumn('العقار', flex: 2),
                    WebTableColumn('المبلغ', flex: 2, align: TextAlign.end),
                    WebTableColumn('', flex: 1, align: TextAlign.center),
                  ],
                  rows: monthExpenses
                      .take(60)
                      .map(
                        (expense) => [
                          Text(
                            formatDate(expense.date),
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                          Text(
                            expense.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          WebPill(
                            label: expense.categoryLabel,
                            color: AppColors.textSecondary,
                          ),
                          Text(
                            expense.compoundName ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                          Text(
                            moneyText(expense.amount),
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.danger,
                            ),
                          ),
                          WebRowAction(
                            icon: Icons.delete_outline_rounded,
                            tooltip: tr('حذف المصروف'),
                            color: AppColors.danger,
                            onTap: () => _deleteExpense(expense),
                          ),
                        ],
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _generateInvoices(Portfolio portfolio) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('توليد فواتير الشهر'),
        content: Text(
          'سيتم إنشاء فواتير لجميع العقود النشطة لشهر ${webMonthName(_month)}، مع تجاوز العقود التي لديها فاتورة لهذا الشهر بالفعل.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('توليد'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final created = await ref
          .read(repositoryProvider)
          .generateInvoices(month: _month);
      await _refresh();
      if (mounted) {
        showSuccess(
          context,
          created == 0
              ? 'كل العقود لديها فواتير لهذا الشهر'
              : 'تم توليد $created فاتورة',
        );
      }
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    }
  }

  Future<void> _recordPayment(Invoice invoice) async {
    final recorded = await showDialog<bool>(
      context: context,
      builder: (_) => _RecordPaymentDialog(
        repository: ref.read(repositoryProvider),
        invoice: invoice,
      ),
    );
    if (recorded == true && mounted) {
      await _refresh();
      if (mounted) showSuccess(context, 'تم تسجيل الدفعة وتحديث حالة الفاتورة');
    }
  }

  Future<void> _addExpense(Portfolio portfolio) async {
    if (portfolio.compounds.isEmpty) {
      showError(context, 'لا توجد عقارات مسجلة بعد');
      return;
    }
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _AddExpenseDialog(
        repository: ref.read(repositoryProvider),
        compounds: portfolio.compounds,
      ),
    );
    if (added == true && mounted) {
      await _refresh();
      if (mounted) showSuccess(context, 'تم إضافة المصروف');
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المصروف'),
        content: Text('هل تريد حذف «${expense.title}» بقيمة ${moneyText(expense.amount)}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(repositoryProvider).deleteExpense(expense.id);
      await _refresh();
      if (mounted) showSuccess(context, 'تم حذف المصروف');
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    }
  }
}

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onReset,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.navy850.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: tr('الشهر السابق'),
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            color: AppColors.textSecondary,
            visualDensity: VisualDensity.compact,
          ),
          InkWell(
            onTap: onReset,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                webMonthName(month),
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gold,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: tr('الشهر التالي'),
            onPressed: onNext,
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            color: AppColors.textSecondary,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _InvoiceCell extends StatelessWidget {
  const _InvoiceCell({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          invoice.number,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          invoice.dueDate == null
              ? formatDate(invoice.invoiceDate)
              : 'استحقاق ${formatDate(invoice.dueDate!)}',
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 9,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          moneyText(value),
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _RecordPaymentDialog extends StatefulWidget {
  const _RecordPaymentDialog({
    required this.repository,
    required this.invoice,
  });

  final SupabaseRepository repository;
  final Invoice invoice;

  @override
  State<_RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<_RecordPaymentDialog> {
  late final _amount = TextEditingController(
    text: widget.invoice.remaining.toStringAsFixed(0),
  );
  final _notes = TextEditingController();
  String _method = 'cash';
  DateTime _date = DateTime.now();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'أدخل مبلغاً صحيحاً');
      return;
    }
    if (amount > widget.invoice.remaining + 0.5) {
      setState(() => _error = 'المبلغ أكبر من المتبقي على الفاتورة');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.recordInvoicePayment(
        invoiceId: widget.invoice.id,
        amount: amount,
        method: _method,
        date: _date,
        notes: _notes.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyError(error);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('تسجيل دفعة · ${widget.invoice.number}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .03),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.invoice.tenantName ?? 'مستأجر',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      'المتبقي ${moneyText(widget.invoice.remaining)}',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                        color: AppColors.pending,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _amount,
                enabled: !_loading,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: tr('المبلغ'),
                  prefixIcon: Icon(Icons.payments_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                value: _method,
                isExpanded: true,
                dropdownColor: AppColors.navy800,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  labelText: tr('طريقة الدفع'),
                  prefixIcon: Icon(Icons.credit_card_rounded),
                ),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('نقداً')),
                  DropdownMenuItem(value: 'transfer', child: Text('تحويل بنكي')),
                  DropdownMenuItem(value: 'card', child: Text('بطاقة')),
                  DropdownMenuItem(value: 'cheque', child: Text('صك')),
                ],
                onChanged: _loading
                    ? null
                    : (value) => setState(() => _method = value ?? _method),
              ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                onTap: _loading ? null : _pickDate,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: tr('تاريخ الدفع'),
                    prefixIcon: Icon(Icons.event_rounded),
                  ),
                  child: Text(
                    formatDate(_date),
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _notes,
                enabled: !_loading,
                maxLines: 2,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: tr('ملاحظات (اختياري)'),
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    height: 1.5,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('تسجيل'),
        ),
      ],
    );
  }
}

class _AddExpenseDialog extends StatefulWidget {
  const _AddExpenseDialog({
    required this.repository,
    required this.compounds,
  });

  final SupabaseRepository repository;
  final List<Compound> compounds;

  @override
  State<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
  late String _compoundId = widget.compounds.first.id;
  String _category = 'maintenance';
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final amount = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (title.length < 3) {
      setState(() => _error = 'أدخل بيان المصروف');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'أدخل مبلغاً صحيحاً');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.addExpense(
        compoundId: _compoundId,
        category: _category,
        title: title,
        amount: amount,
        date: _date,
        notes: _notes.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyError(error);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة مصروف'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _compoundId,
                isExpanded: true,
                dropdownColor: AppColors.navy800,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  labelText: tr('العقار'),
                  prefixIcon: Icon(Icons.location_city_rounded),
                ),
                items: widget.compounds
                    .map(
                      (compound) => DropdownMenuItem(
                        value: compound.id,
                        child: Text(
                          compound.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _loading
                    ? null
                    : (value) =>
                        setState(() => _compoundId = value ?? _compoundId),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                value: _category,
                isExpanded: true,
                dropdownColor: AppColors.navy800,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  labelText: tr('التصنيف'),
                  prefixIcon: Icon(Icons.category_rounded),
                ),
                items: expenseCategories.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: _loading
                    ? null
                    : (value) => setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _title,
                enabled: !_loading,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: tr('البيان'),
                  prefixIcon: Icon(Icons.description_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _amount,
                enabled: !_loading,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: tr('المبلغ'),
                  prefixIcon: Icon(Icons.payments_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                onTap: _loading ? null : _pickDate,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: tr('التاريخ'),
                    prefixIcon: Icon(Icons.event_rounded),
                  ),
                  child: Text(
                    formatDate(_date),
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _notes,
                enabled: !_loading,
                maxLines: 2,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: tr('ملاحظات (اختياري)'),
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    height: 1.5,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('إضافة'),
        ),
      ],
    );
  }
}
