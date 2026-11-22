import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/building_report.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';
import 'manager_expense_sheet.dart';
import 'record_payment_sheet.dart';
import 'vacate_tenant_sheet.dart';
import '../../core/i18n/i18n.dart';

class ManagerAccountingScreen extends ConsumerStatefulWidget {
  const ManagerAccountingScreen({super.key, required this.profile});

  final AppProfile profile;

  @override
  ConsumerState<ManagerAccountingScreen> createState() =>
      _ManagerAccountingScreenState();
}

class _ManagerAccountingScreenState
    extends ConsumerState<ManagerAccountingScreen> {
  static const _allBuildings = '__all__';

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int _tab = 0;
  String _buildingId = _allBuildings;

  String? get _buildingFilter =>
      _buildingId == _allBuildings ? null : _buildingId;

  bool _inMonth(DateTime date) =>
      date.year == _month.year && date.month == _month.month;

  Future<void> _refresh() async {
    ref.invalidate(managerSnapshotProvider);
    ref.invalidate(managerAccountingProvider);
    await ref.read(managerAccountingProvider.future);
  }

  void _invalidateAll() {
    ref.invalidate(managerSnapshotProvider);
    ref.invalidate(managerAccountingProvider);
    ref.invalidate(ownerSnapshotProvider);
    ref.invalidate(ownerDashboardProvider);
    ref.invalidate(tenantSnapshotProvider);
  }

  Invoice? _monthInvoice(ManagerAccountingData data, String tenantId) {
    for (final invoice in data.invoices) {
      if (invoice.tenantId == tenantId &&
          _inMonth(invoice.invoiceDate) &&
          !invoice.isPaid) {
        return invoice;
      }
    }
    return null;
  }

  Future<void> _recordPayment(TenantRecord tenant, Invoice? invoice) async {
    final saved = await showRecordPaymentSheet(
      context: context,
      repository: ref.read(repositoryProvider),
      tenant: tenant,
      expected: tenant.lease?.monthlyRent ?? tenant.apartment.rentAmount,
      invoice: invoice,
    );
    if (!saved || !mounted) return;
    _invalidateAll();
    showSuccess(context, 'تم تسجيل الدفعة بنجاح');
  }

  Future<void> _vacateTenant(TenantRecord tenant) async {
    final saved = await showVacateTenantSheet(
      context: context,
      repository: ref.read(repositoryProvider),
      tenant: tenant,
    );
    if (!saved || !mounted) return;
    _invalidateAll();
    showSuccess(context, 'تم إخلاء الشقة وتحويلها إلى فارغة، وحُفظ سجل المستأجر');
  }

  Future<void> _addExpense(Portfolio portfolio) async {    final saved = await showAddExpenseSheet(
      context: context,
      repository: ref.read(repositoryProvider),
      portfolio: portfolio,
      initialDate: _month,
    );
    if (!saved || !mounted) return;
    _invalidateAll();
    showSuccess(context, 'تم تسجيل المصروف بنجاح');
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.navy800,
        title: const Text(
          'حذف المصروف',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'هل تريد حذف «${expense.title}»؟',
          style: const TextStyle(
            fontFamily: 'Tajawal',
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'إلغاء',
              style: TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'حذف',
              style: TextStyle(
                fontFamily: 'Tajawal',
                color: AppColors.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(repositoryProvider).deleteExpense(expense.id);
      _invalidateAll();
      if (mounted) showSuccess(context, 'تم حذف المصروف');
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(managerAccountingProvider);
    return async.when(
      loading: () => const LoadingList(count: 4),
      error: (error, _) => ErrorView(
        message: friendlyError(error),
        onRetry: () => ref.invalidate(managerAccountingProvider),
      ),
      data: (data) => RefreshIndicator(
        color: AppColors.gold,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
          children: [
            PremiumHeader(
              name: widget.profile.displayName,
              roleLabel: 'مدير',
              subtitle: 'التحصيل والمصاريف وتقارير البنايات',
              avatarUrl: widget.profile.avatarUrl,
            ),
            const SizedBox(height: AppSpacing.lg),
            _MonthBar(
              month: _month,
              onPrevious: () => setState(() => _month = addMonthsClamped(_month, -1)),
              onNext: () => setState(() => _month = addMonthsClamped(_month, 1)),
              onReset: () => setState(
                () => _month = DateTime(DateTime.now().year, DateTime.now().month),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SectionTabs(
              value: _tab,
              onChanged: (value) => setState(() => _tab = value),
            ),
            const SizedBox(height: AppSpacing.md),
            _BuildingFilter(
              portfolio: data.snapshot.portfolio,
              value: _buildingId,
              allValue: _allBuildings,
              onChanged: (value) => setState(() => _buildingId = value),
            ),
            const SizedBox(height: AppSpacing.md),
            ...switch (_tab) {
              1 => _buildExpenses(data),
              2 => _buildReport(data),
              _ => _buildCollection(data),
            },
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- collection

  List<Widget> _buildCollection(ManagerAccountingData data) {
    final filter = _buildingFilter;
    final tenants = data.snapshot.tenants
        .where((tenant) =>
            filter == null || tenant.apartment.buildingId == filter)
        .toList()
      ..sort((a, b) => a.apartment.label.compareTo(b.apartment.label));

    final paidByTenant = <String, double>{};
    for (final payment in data.snapshot.payments) {
      if (!_inMonth(payment.paymentDate)) continue;
      paidByTenant[payment.tenantId] =
          (paidByTenant[payment.tenantId] ?? 0) + payment.amount;
    }

    double expectedOf(TenantRecord tenant) =>
        tenant.lease?.monthlyRent ?? tenant.apartment.rentAmount;

    final expected =
        tenants.fold<double>(0, (sum, tenant) => sum + expectedOf(tenant));
    final collected = tenants.fold<double>(
        0, (sum, tenant) => sum + (paidByTenant[tenant.profile.id] ?? 0));
    final remaining = (expected - collected).clamp(0, double.infinity);

    return [
      Row(
        children: [
          Expanded(
            child: StatCard(
              label: 'الإيجار المستحق',
              value: formatMoney(expected, compact: true),
              icon: Icons.request_quote_rounded,
              color: AppColors.info,
              compact: true,
              caption: '${tenants.length} مستأجر',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: StatCard(
              label: 'المحصل هذا الشهر',
              value: formatMoney(collected, compact: true),
              icon: Icons.check_circle_rounded,
              color: AppColors.occupied,
              compact: true,
              caption: formatMonth(_month),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          Expanded(
            child: StatCard(
              label: 'المتبقي للتحصيل',
              value: formatMoney(remaining, compact: true),
              icon: Icons.hourglass_bottom_rounded,
              color: remaining > 0 ? AppColors.pending : AppColors.occupied,
              compact: true,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: StatCard(
              label: 'نسبة التحصيل',
              value: expected <= 0
                  ? '—'
                  : percent((collected / expected).clamp(0, 1)),
              icon: Icons.speed_rounded,
              color: AppColors.gold,
              compact: true,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      const SectionHeader(
        title: 'تحصيل الإيجارات',
        subtitle: 'اضغط «تسجيل دفعة» عند استلام الإيجار من المستأجر',
      ),
      const SizedBox(height: AppSpacing.md),
      if (tenants.isEmpty)
        const EmptyState(
          icon: Icons.people_outline_rounded,
          title: 'لا يوجد مستأجرون',
          message: 'لا توجد شقق مؤجرة ضمن نطاق الإدارة المحدد.',
        )
      else
        for (final tenant in tenants)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _CollectionTile(
              tenant: tenant,
              month: _month,
              due: expectedOf(tenant),
              paid: paidByTenant[tenant.profile.id] ?? 0,
              invoice: _monthInvoice(data, tenant.profile.id),
              onRecord: () =>
                  _recordPayment(tenant, _monthInvoice(data, tenant.profile.id)),
              onVacate: () => _vacateTenant(tenant),
            ),
          ),
    ];
  }

  // ---------------------------------------------------------------- expenses

  List<Widget> _buildExpenses(ManagerAccountingData data) {
    final filter = _buildingFilter;
    final expenses = data.expenses
        .where((expense) =>
            _inMonth(expense.date) &&
            (filter == null || expense.buildingId == filter))
        .toList();
    final total =
        expenses.fold<double>(0, (sum, expense) => sum + expense.amount);

    return [
      Row(
        children: [
          Expanded(
            child: StatCard(
              label: 'مصاريف الشهر',
              value: formatMoney(total, compact: true),
              icon: Icons.account_balance_wallet_rounded,
              color: AppColors.pending,
              compact: true,
              caption: formatMonth(_month),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: StatCard(
              label: 'عدد المصاريف',
              value: '${expenses.length}',
              icon: Icons.receipt_long_rounded,
              color: AppColors.info,
              compact: true,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      GoldButton(
        label: 'إضافة مصروف',
        icon: Icons.add_card_rounded,
        onPressed: () => _addExpense(data.snapshot.portfolio),
      ),
      const SizedBox(height: AppSpacing.lg),
      SectionHeader(
        title: 'مصاريف ${formatMonth(_month)}',
        subtitle: 'مصاريف مرتبطة ببناية أو عامة للمجمع',
      ),
      const SizedBox(height: AppSpacing.md),
      if (expenses.isEmpty)
        const EmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'لا توجد مصاريف مسجلة',
          message: 'سجل صيانة أو فاتورة أو أي مصروف على البناية ليظهر في التقرير.',
        )
      else
        for (final expense in expenses)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _ExpenseTile(
              expense: expense,
              canDelete: expense.createdBy == widget.profile.id,
              onDelete: () => _deleteExpense(expense),
            ),
          ),
    ];
  }

  // ------------------------------------------------------------------ report

  List<Widget> _buildReport(ManagerAccountingData data) {
    final reports = buildBuildingReports(
      portfolio: data.snapshot.portfolio,
      tenants: data.snapshot.tenants,
      payments: data.snapshot.payments,
      expenses: data.expenses,
      month: _month,
    );
    final filter = _buildingFilter;
    final compounds = <({CompoundReport compound, List<BuildingReport> buildings})>[];
    for (final compound in reports) {
      final buildings = compound.buildings
          .where((building) => filter == null || building.id == filter)
          .toList();
      if (buildings.isEmpty) continue;
      compounds.add((compound: compound, buildings: buildings));
    }

    final buildings = [for (final entry in compounds) ...entry.buildings];
    final due = buildings.fold<double>(0, (sum, b) => sum + b.due);
    final collected = buildings.fold<double>(0, (sum, b) => sum + b.collected);
    final expenses = filter == null
        ? compounds.fold<double>(
            0, (sum, entry) => sum + entry.compound.totalExpenses)
        : buildings.fold<double>(0, (sum, b) => sum + b.expenses);
    final net = collected - expenses;

    return [
      Row(
        children: [
          Expanded(
            child: StatCard(
              label: 'الواردات',
              value: formatMoney(collected, compact: true),
              icon: Icons.trending_up_rounded,
              color: AppColors.occupied,
              compact: true,
              caption: formatMonth(_month),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: StatCard(
              label: 'المصاريف',
              value: formatMoney(expenses, compact: true),
              icon: Icons.trending_down_rounded,
              color: AppColors.pending,
              compact: true,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          Expanded(
            child: StatCard(
              label: 'صافي الربح',
              value: formatMoney(net, compact: true),
              icon: Icons.savings_rounded,
              color: net >= 0 ? AppColors.gold : AppColors.danger,
              compact: true,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: StatCard(
              label: 'غير محصل من المستحق',
              value: formatMoney((due - collected).clamp(0, double.infinity),
                  compact: true),
              icon: Icons.pending_actions_rounded,
              color: AppColors.info,
              compact: true,
              caption: 'مستحق ${formatMoney(due, compact: true)}',
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      SectionHeader(
        title: 'تقرير البنايات — ${formatMonth(_month)}',
        subtitle: 'الواردات من الدفعات المسجلة، والمصاريف على البناية أو المجمع',
      ),
      const SizedBox(height: AppSpacing.md),
      if (compounds.isEmpty)
        const EmptyState(
          icon: Icons.assessment_rounded,
          title: 'لا توجد بيانات',
          message: 'لا توجد بنايات ضمن نطاق الإدارة المحدد.',
        )
      else
        for (final entry in compounds)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _CompoundReportCard(
              name: entry.compound.name,
              buildings: entry.buildings,
              generalExpenses:
                  filter == null ? entry.compound.generalExpenses : 0,
            ),
          ),
    ];
  }
}

// ---------------------------------------------------------------- month bar

class _MonthBar extends StatelessWidget {
  const _MonthBar({
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
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          IconButton(
            tooltip: tr('الشهر السابق'),
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_right_rounded, size: 22),
            color: AppColors.textSecondary,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: InkWell(
              onTap: onReset,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(
                      formatMonth(month),
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'اضغط للعودة للشهر الحالي',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 9,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: tr('الشهر التالي'),
            onPressed: onNext,
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
            color: AppColors.textSecondary,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------- tabs

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const _items = [
    (label: 'التحصيل', icon: Icons.payments_rounded),
    (label: 'المصاريف', icon: Icons.receipt_long_rounded),
    (label: 'التقرير', icon: Icons.assessment_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.navy850.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 40,
                  decoration: BoxDecoration(
                    color: value == i
                        ? AppColors.gold.withValues(alpha: .16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: value == i
                          ? AppColors.gold.withValues(alpha: .45)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _items[i].icon,
                        size: 15,
                        color: value == i ? AppColors.gold : AppColors.textMuted,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          _items[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: value == i
                                ? AppColors.gold
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ building filter

class _BuildingFilter extends StatelessWidget {
  const _BuildingFilter({
    required this.portfolio,
    required this.value,
    required this.allValue,
    required this.onChanged,
  });

  final Portfolio portfolio;
  final String value;
  final String allValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <({String id, String label})>[
      (id: allValue, label: 'كل البنايات'),
      for (final compound in portfolio.compounds)
        for (final building in compound.buildings)
          (
            id: building.id,
            label: portfolio.compounds.length > 1
                ? '${building.name} · ${compound.name}'
                : building.name,
          ),
    ];
    final selected =
        options.any((option) => option.id == value) ? value : allValue;
    return GlassCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_rounded,
              size: 18, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selected,
                isExpanded: true,
                dropdownColor: AppColors.navy800,
                borderRadius: BorderRadius.circular(AppRadius.md),
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
                items: [
                  for (final option in options)
                    DropdownMenuItem(
                      value: option.id,
                      child: Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Tajawal'),
                      ),
                    ),
                ],
                onChanged: (next) {
                  if (next != null) onChanged(next);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ collection tile

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.tenant,
    required this.month,
    required this.due,
    required this.paid,
    required this.invoice,
    required this.onRecord,
    required this.onVacate,
  });

  final TenantRecord tenant;
  final DateTime month;
  final double due;
  final double paid;
  final Invoice? invoice;
  final VoidCallback onRecord;
  final VoidCallback onVacate;

  @override
  Widget build(BuildContext context) {
    final remaining = (due - paid).clamp(0, double.infinity);
    final status = due <= 0
        ? (label: 'لا يوجد إيجار', color: AppColors.textMuted)
        : remaining <= 0
            ? (label: 'مكتمل', color: AppColors.occupied)
            : paid > 0
                ? (label: 'جزئي', color: AppColors.pending)
                : (label: 'غير مسدد', color: AppColors.vacant);
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.occupied.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_rounded,
                    color: AppColors.occupied, size: 19),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant.profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tenant.apartment.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: status.label,
                color: status.color,
                compact: true,
              ),
              PopupMenuButton<String>(
                tooltip: tr('خيارات المستأجر'),
                color: AppColors.navy800,
                icon: const Icon(Icons.more_vert_rounded,
                    size: 20, color: AppColors.textMuted),
                onSelected: (value) {
                  if (value == 'vacate') onVacate();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'vacate',
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded,
                            size: 18, color: AppColors.danger),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          'إخلاء الشقة وأرشفة المستأجر',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 12,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _AmountCell(
                  label: 'المستحق',
                  value: formatMoney(due),
                  color: AppColors.textSecondary,
                ),
              ),
              Expanded(
                child: _AmountCell(
                  label: 'المحصل',
                  value: formatMoney(paid),
                  color: AppColors.occupied,
                ),
              ),
              Expanded(
                child: _AmountCell(
                  label: 'المتبقي',
                  value: formatMoney(remaining),
                  color: remaining > 0 ? AppColors.pending : AppColors.occupied,
                ),
              ),
            ],
          ),
          if (invoice != null) ...[
            const SizedBox(height: 2),
            Text(
              'فاتورة ${invoice!.number} · ${formatMoney(invoice!.remaining)} متبقٍ',
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 9.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  paid > 0
                      ? 'تم التحصيل خلال ${formatMonth(month)}'
                      : 'لم تُسجل دفعة خلال ${formatMonth(month)}',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 9.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              SoftButton(
                label: paid > 0 ? 'إضافة دفعة' : 'تسجيل دفعة',
                icon: Icons.receipt_long_rounded,
                color: AppColors.occupied,
                height: 38,
                expand: false,
                onPressed: onRecord,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountCell extends StatelessWidget {
  const _AmountCell({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
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

// --------------------------------------------------------------- expense tile

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.expense,
    required this.canDelete,
    required this.onDelete,
  });

  final Expense expense;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.pending.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.request_quote_rounded,
                color: AppColors.pending, size: 19),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${expense.categoryLabel} · ${expense.scopeLabel} · ${formatDate(expense.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 9.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            formatMoney(expense.amount, withCurrency: true),
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.pending,
            ),
          ),
          if (canDelete)
            IconButton(
              tooltip: tr('حذف'),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 19),
              color: AppColors.textMuted,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- report widgets

class _CompoundReportCard extends StatelessWidget {
  const _CompoundReportCard({
    required this.name,
    required this.buildings,
    required this.generalExpenses,
  });

  final String name;
  final List<BuildingReport> buildings;
  final double generalExpenses;

  @override
  Widget build(BuildContext context) {
    final due = buildings.fold<double>(0, (sum, b) => sum + b.due);
    final collected = buildings.fold<double>(0, (sum, b) => sum + b.collected);
    final expenses = buildings.fold<double>(0, (sum, b) => sum + b.expenses) +
        generalExpenses;
    final net = collected - expenses;
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_city_rounded,
                    color: AppColors.gold, size: 19),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${buildings.length} بناية · ${buildings.fold<int>(0, (sum, b) => sum + b.units)} وحدة',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMoney(net, compact: true),
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: net >= 0 ? AppColors.occupied : AppColors.danger,
                    ),
                  ),
                  const Text(
                    'الصافي',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 9,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(height: 1, color: Color(0x1FFFFFFF)),
          ),
          if (buildings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                'لا توجد بنايات مسجلة في هذا المجمع.',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            )
          else
            for (var i = 0; i < buildings.length; i++) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Divider(height: 1, color: Color(0x14FFFFFF)),
                ),
              _BuildingReportRow(building: buildings[i]),
            ],
          if (generalExpenses > 0) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Divider(height: 1, color: Color(0x14FFFFFF)),
            ),
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded,
                    size: 16, color: AppColors.textMuted),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text(
                    'مصاريف عامة للمجمع',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  formatMoney(generalExpenses, withCurrency: true),
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.pending,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.navy850.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _AmountCell(
                    label: 'المستحق',
                    value: formatMoney(due, compact: true),
                    color: AppColors.textPrimary,
                  ),
                ),
                Expanded(
                  child: _AmountCell(
                    label: 'الواردات',
                    value: formatMoney(collected, compact: true),
                    color: AppColors.occupied,
                  ),
                ),
                Expanded(
                  child: _AmountCell(
                    label: 'المصاريف',
                    value: formatMoney(expenses, compact: true),
                    color: AppColors.pending,
                  ),
                ),
                Expanded(
                  child: _AmountCell(
                    label: 'الصافي',
                    value: formatMoney(net, compact: true),
                    color:
                        net >= 0 ? AppColors.occupied : AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BuildingReportRow extends StatelessWidget {
  const _BuildingReportRow({required this.building});

  final BuildingReport building;

  @override
  Widget build(BuildContext context) {
    final outstanding = building.outstanding;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.apartment_rounded,
                  size: 17, color: AppColors.info),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      building.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${building.occupied}/${building.units} مشغولة'
                      '${outstanding > 0 ? ' · متبقي ${formatMoney(outstanding, compact: true)}' : ''}',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 9.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatMoney(building.net, compact: true),
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: building.net >= 0
                      ? AppColors.occupied
                      : AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _AmountCell(
                  label: 'المستحق',
                  value: formatMoney(building.due, compact: true),
                  color: AppColors.textSecondary,
                ),
              ),
              Expanded(
                child: _AmountCell(
                  label: 'الواردات',
                  value: formatMoney(building.collected, compact: true),
                  color: AppColors.occupied,
                ),
              ),
              Expanded(
                child: _AmountCell(
                  label: 'المصاريف',
                  value: formatMoney(building.expenses, compact: true),
                  color: AppColors.pending,
                ),
              ),
              Expanded(
                child: _AmountCell(
                  label: 'الصافي',
                  value: formatMoney(building.net, compact: true),
                  color: building.net >= 0
                      ? AppColors.occupied
                      : AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
