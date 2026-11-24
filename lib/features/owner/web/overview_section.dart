import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_utils.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/premium_widgets.dart';
import '../../../data/models.dart';
import '../../shared/request_card.dart';
import '../../shared/request_detail_screen.dart';
import 'web_ui.dart';

class OverviewSection extends ConsumerWidget {
  const OverviewSection({
    super.key,
    required this.profile,
    required this.onNavigate,
  });

  final AppProfile profile;
  final ValueChanged<OwnerSection> onNavigate;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(ownerSnapshotProvider);
    ref.invalidate(ownerDashboardProvider);
    await ref.read(ownerDashboardProvider.future);
  }

  Future<void> _openRequest(
    BuildContext context,
    WidgetRef ref,
    MaintenanceRequest request,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            RequestDetailScreen(requestId: request.id, viewer: profile),
      ),
    );
    ref.invalidate(ownerSnapshotProvider);
    ref.invalidate(ownerDashboardProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ownerDashboardProvider);
    final country = ref.watch(ownerCountryProvider);
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
        final snapshot = data.snapshot;
        final allPortfolio = snapshot.portfolio;
        final compounds =
            allPortfolio.compounds.where((c) => c.country == country).toList();
        final portfolio = Portfolio(compounds);
        final invoices =
            data.invoices.where((invoice) => invoice.country == country).toList();
        final expenses =
            data.expenses.where((expense) => expense.country == country).toList();
        final tenants = snapshot.tenants
            .where((tenant) => tenant.apartment.country == country)
            .toList();
        final collectedThisMonth = invoices
            .where((invoice) => isSameMonth(invoice.invoiceDate, DateTime.now()))
            .fold<double>(0, (sum, invoice) => sum + invoice.paidAmount);
        final collectedTotal =
            invoices.fold<double>(0, (sum, invoice) => sum + invoice.paidAmount);
        final outstandingTotal =
            invoices.fold<double>(0, (sum, invoice) => sum + invoice.remaining);
        final expensesTotal =
            expenses.fold<double>(0, (sum, expense) => sum + expense.amount);
        final netTotal = collectedTotal - expensesTotal;
        final overdueCount = invoices.where((invoice) => invoice.isOverdue).length;
        final now = DateTime.now();
        final months =
            List.generate(6, (index) => addMonths(startOfMonth(now), index - 5));
        final collectedSeries = months
            .map((month) => invoices
                .where((invoice) => isSameMonth(invoice.invoiceDate, month))
                .fold<double>(0, (sum, invoice) => sum + invoice.paidAmount))
            .toList();
        final expenseSeries = months
            .map((month) => expenses
                .where((expense) => isSameMonth(expense.date, month))
                .fold<double>(0, (sum, expense) => sum + expense.amount))
            .toList();
        final recentInvoices = invoices.take(6).toList();

        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () => _refresh(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              WebPageHeader(
                title: 'مرحباً، ${profile.displayName}',
                subtitle:
                    'ملخص تنفيذي لأداء ${portfolio.compounds.length} عقار و${portfolio.total} وحدة سكنية في ${country.name(english: I18n.isEnglish)}',
                actions: [
                  OutlinedButton.icon(
                    onPressed: () => _refresh(ref),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('تحديث'),
                  ),
                  FilledButton.icon(
                    onPressed: () => onNavigate(OwnerSection.accounting),
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    label: const Text('المحاسبة'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              WebKpiGrid(
                children: [
                  WebKpiCard(
                    label: 'إجمالي التحصيل',
                    value: moneyText(collectedTotal, country: country),
                    icon: Icons.savings_rounded,
                    color: AppColors.occupied,
                    caption: 'منذ بداية السجل',
                  ),
                  WebKpiCard(
                    label: 'مبالغ غير محصّلة',
                    value: moneyText(outstandingTotal, country: country),
                    icon: Icons.hourglass_bottom_rounded,
                    color: AppColors.pending,
                    caption: '$overdueCount فاتورة متأخرة',
                    onTap: () => onNavigate(OwnerSection.accounting),
                  ),
                  WebKpiCard(
                    label: 'المصروفات',
                    value: moneyText(expensesTotal, country: country),
                    icon: Icons.trending_down_rounded,
                    color: AppColors.danger,
                    caption: '${expenses.length} عملية',
                    onTap: () => onNavigate(OwnerSection.accounting),
                  ),
                  WebKpiCard(
                    label: 'الصافي',
                    value: moneyText(netTotal, country: country),
                    icon: Icons.account_balance_rounded,
                    color: netTotal >= 0
                        ? AppColors.gold
                        : AppColors.danger,
                    caption: 'التحصيل − المصروفات',
                  ),
                  WebKpiCard(
                    label: 'نسبة الإشغال',
                    value: percent(portfolio.occupancyRate),
                    icon: Icons.pie_chart_rounded,
                    color: AppColors.info,
                    caption: '${portfolio.occupied} من ${portfolio.total} · ${tenants.length} مستأجر',
                  ),
                  WebKpiCard(
                    label: 'الإيجار الشهري المتوقع',
                    value: moneyText(portfolio.monthlyExpected, country: country),
                    icon: Icons.calendar_month_rounded,
                    color: AppColors.reserved,
                    caption: '${portfolio.vacant} وحدة فارغة',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              WebColumns(
                firstFlex: 3,
                secondFlex: 2,
                first: WebPanel(
                  title: 'أداء المحفظة',
                  subtitle: 'الإشغال والإيراد المتوقع',
                  glowColor: AppColors.gold,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final details = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                moneyText(portfolio.monthlyExpected,
                                    country: country),
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.gold,
                                ),
                              ),
                              const Text(
                                'الإيراد الشهري المتوقع من الوحدات المؤجرة',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              WebInfoTile(
                                icon: Icons.savings_rounded,
                                label: 'محصّل هذا الشهر',
                                value: moneyText(collectedThisMonth,
                                    country: country),
                                color: AppColors.occupied,
                              ),
                              const SizedBox(height: 6),
                              WebInfoTile(
                                icon: Icons.warning_amber_rounded,
                                label: 'مستأجرون متأخرون',
                                value: '${snapshot.overdueTenants}',
                                color: snapshot.overdueTenants == 0
                                    ? AppColors.occupied
                                    : AppColors.danger,
                              ),
                            ],
                          );
                          if (constraints.maxWidth < 380) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: OccupancyRing(
                                    rate: portfolio.occupancyRate,
                                    size: 108,
                                    label: 'الإشغال',
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                details,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              OccupancyRing(
                                rate: portfolio.occupancyRate,
                                size: 118,
                                label: 'الإشغال',
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(child: details),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          _PortfolioMetric(
                            label: 'العقارات',
                            value: '${portfolio.compounds.length}',
                            icon: Icons.location_city_rounded,
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: 8),
                          _PortfolioMetric(
                            label: 'العمارات',
                            value: '${portfolio.buildingsCount}',
                            icon: Icons.apartment_rounded,
                            color: AppColors.info,
                          ),
                          const SizedBox(width: 8),
                          _PortfolioMetric(
                            label: 'الشقق',
                            value: '${portfolio.total}',
                            icon: Icons.meeting_room_rounded,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 8),
                          _PortfolioMetric(
                            label: 'فارغة',
                            value: '${portfolio.vacant}',
                            icon: Icons.no_meeting_room_rounded,
                            color: AppColors.vacant,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                second: WebPanel(
                  title: 'بانتظار موافقتك',
                  subtitle: '${snapshot.pendingApprovals.length} طلب صيانة',
                  action: snapshot.pendingApprovals.isEmpty
                      ? null
                      : TextButton(
                          onPressed: () => onNavigate(OwnerSection.requests),
                          child: const Text('عرض الكل'),
                        ),
                  child: snapshot.pendingApprovals.isEmpty
                      ? const WebEmpty(
                          icon: Icons.task_alt_rounded,
                          title: 'لا توجد موافقات معلقة',
                          message: 'كل طلبات الصيانة تمت معالجتها.',
                        )
                      : Column(
                          children: snapshot.pendingApprovals
                              .take(3)
                              .map(
                                (request) => Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: AppSpacing.sm),
                                  child: RequestCard(
                                    request: request,
                                    showTenant: false,
                                    onTap: () =>
                                        _openRequest(context, ref, request),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              WebColumns(
                first: WebPanel(
                  title: 'الحركة المالية',
                  subtitle: 'آخر 6 أشهر',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const _Legend(
                            color: AppColors.occupied,
                            label: 'التحصيل',
                          ),
                          const SizedBox(width: AppSpacing.md),
                          const _Legend(
                            color: AppColors.danger,
                            label: 'المصروفات',
                          ),
                          const Spacer(),
                          Text(
                            'صافي ${moneyText(collectedSeries.fold(0.0, (a, b) => a + b) - expenseSeries.fold(0.0, (a, b) => a + b), country: country)}',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                MiniBars(
                                  values: collectedSeries,
                                  labels: months.map(webShortMonth).toList(),
                                  color: AppColors.occupied,
                                  height: 110,
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'المحصّل',
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 10,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              children: [
                                MiniBars(
                                  values: expenseSeries,
                                  labels: months.map(webShortMonth).toList(),
                                  color: AppColors.danger,
                                  height: 110,
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'المصروف',
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 10,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                second: WebPanel(
                  title: 'توزيع الوحدات',
                  subtitle: 'حسب الحالة',
                  child: Column(
                    children: [
                      _StatusRow(
                        label: 'مؤجرة',
                        value: portfolio.occupied,
                        total: portfolio.total,
                        color: AppColors.occupied,
                      ),
                      const SizedBox(height: 10),
                      _StatusRow(
                        label: 'فارغة',
                        value: portfolio.vacant,
                        total: portfolio.total,
                        color: AppColors.vacant,
                      ),
                      const SizedBox(height: 10),
                      _StatusRow(
                        label: 'صيانة',
                        value: portfolio.maintenance,
                        total: portfolio.total,
                        color: AppColors.pending,
                      ),
                      const SizedBox(height: 10),
                      _StatusRow(
                        label: 'محجوزة',
                        value: portfolio.reserved,
                        total: portfolio.total,
                        color: AppColors.reserved,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              WebPanel(
                title: 'أحدث الفواتير',
                subtitle: 'آخر الفواتير الصادرة على مستوى المحفظة',
                action: TextButton(
                  onPressed: () => onNavigate(OwnerSection.accounting),
                  child: const Text('إدارة الفواتير'),
                ),
                child: WebTable(
                  empty: const WebEmpty(
                    icon: Icons.receipt_long_rounded,
                    title: 'لا توجد فواتير بعد',
                    message:
                        'ولّد فواتير الشهر من قسم المحاسبة لتظهر هنا وفي حساب المستأجر.',
                  ),
                  columns: const [
                    WebTableColumn('الفاتورة', flex: 2),
                    WebTableColumn('المستأجر', flex: 2),
                    WebTableColumn('الوحدة', flex: 2),
                    WebTableColumn('الإجمالي', flex: 2, align: TextAlign.end),
                    WebTableColumn('الحالة', flex: 2, align: TextAlign.center),
                  ],
                  rows: recentInvoices
                      .map(
                        (invoice) => [
                          _InvoiceNumber(invoice: invoice),
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
                            moneyText(invoice.totalAmount, country: country),
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.gold,
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
}

class _PortfolioMetric extends StatelessWidget {
  const _PortfolioMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: .06)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 9,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
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
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : value / total,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: .06),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _InvoiceNumber extends StatelessWidget {
  const _InvoiceNumber({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          invoice.number,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          formatDate(invoice.invoiceDate),
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
