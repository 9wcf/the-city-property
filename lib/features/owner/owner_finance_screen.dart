import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/i18n/app_country.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/owner_country_view.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';
import '../shared/lease_documents_sheet.dart';
import '../../core/i18n/i18n.dart';

class OwnerFinanceScreen extends ConsumerWidget {
  const OwnerFinanceScreen({super.key, required this.profile});

  final AppProfile profile;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(ownerSnapshotProvider);
    await ref.read(ownerSnapshotProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(ownerSnapshotProvider);
    return snapshotAsync.when(
      loading: () => const LoadingList(count: 4),
      error: (error, _) => ErrorView(
        message: friendlyError(error),
        onRetry: () => ref.invalidate(ownerSnapshotProvider),
      ),
      data: (snapshot) {
        final country = ref.watch(ownerCountryProvider);
        final view = OwnerCountryView.fromSnapshot(snapshot, country);
        return RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المالية',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'التحصيل الشهري وحالة المستأجرين',
                        style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _refresh(ref),
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildCollectionCard(view, country),
            const SizedBox(height: AppSpacing.md),
            _buildTrend(view),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: 'حالة المستأجرين',
              subtitle: '${view.tenants.length} مستأجر نشط',
            ),
            const SizedBox(height: AppSpacing.md),
            if (view.tenants.isEmpty)
              const EmptyState(
                icon: Icons.people_outline_rounded,
                title: 'لا يوجد مستأجرون',
                message: 'سيظهر هنا المستأجرون المرتبطون بالشقق المؤجرة.',
              )
            else
              ...view.tenants.map(
                (tenant) => _TenantPaymentCard(
                  tenant: tenant,
                  onDocuments: tenant.lease == null
                      ? null
                      : () => LeaseDocumentsSheet.show(
                            context,
                            lease: tenant.lease!,
                            tenantName: tenant.profile.displayName,
                          ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: 'سجل الدفعات',
              subtitle: '${view.payments.length} دفعة مسجلة',
            ),
            const SizedBox(height: AppSpacing.md),
            if (view.payments.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long_rounded,
                title: 'لا توجد دفعات بعد',
                message: 'سيقوم المدير بتسجيل الدفعات عند استلام الإيجار.',
              )
            else
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Column(
                  children: view.payments.take(25).map((payment) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.occupied.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(Icons.payments_rounded, color: AppColors.occupied, size: 18),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  payment.tenantName ?? 'مستأجر',
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${formatDate(payment.paymentDate)} · ${payment.methodLabel}'
                                  '${payment.receiptNumber == null ? '' : ' · ${payment.receiptNumber}'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 9, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatMoney(payment.amount,
                                withCurrency: true, country: country),
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.occupied,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      );
      },
    );
  }

  Widget _buildCollectionCard(OwnerCountryView view, AppCountry country) {
    final expected = view.portfolio.monthlyExpected;
    final remaining = (expected - view.collectedThisMonth).clamp(0, double.infinity);
    return GlassCard(
      glowColor: AppColors.occupied,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تحصيل ${formatMonth(DateTime.now())}',
            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(view.collectedThisMonth,
                    withCurrency: true, country: country),
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.occupied,
                ),
              ),
              const Spacer(),
              StatusPill(
                label: percent(view.collectionRate),
                color: view.collectionRate >= .8
                    ? AppColors.occupied
                    : AppColors.pending,
                icon: Icons.trending_up_rounded,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          OccupancyBar(
            rate: view.collectionRate,
            color: AppColors.occupied,
            height: 10,
            label:
                'نسبة التحصيل من المتوقع ${formatMoney(expected, compact: true, country: country)}',
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _FinanceMetric(
                label: 'المتوقع',
                value: formatMoney(expected, compact: true, country: country),
                color: AppColors.gold,
                icon: Icons.track_changes_rounded,
              ),
              const SizedBox(width: AppSpacing.sm),
              _FinanceMetric(
                label: 'المتبقي',
                value:
                    formatMoney(remaining, compact: true, country: country),
                color: AppColors.pending,
                icon: Icons.hourglass_bottom_rounded,
              ),
              const SizedBox(width: AppSpacing.sm),
              _FinanceMetric(
                label: 'متأخرون',
                value: '${view.overdueTenants}',
                color: view.overdueTenants > 0
                    ? AppColors.danger
                    : AppColors.occupied,
                icon: Icons.warning_amber_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrend(OwnerCountryView view) {
    final now = DateTime.now();
    final values = <double>[];
    final labels = <String>[];
    final monthFormat = DateFormat('MMM', 'ar');
    for (var i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final total = view.payments
          .where((p) => p.paymentDate.year == date.year && p.paymentDate.month == date.month)
          .fold<double>(0, (sum, p) => sum + p.amount);
      values.add(total);
      labels.add(monthFormat.format(date));
    }
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'اتجاه التحصيل', subtitle: 'آخر 6 أشهر'),
          const SizedBox(height: AppSpacing.md),
          MiniBars(values: values, labels: labels, height: 100),
        ],
      ),
    );
  }
}

class _FinanceMetric extends StatelessWidget {
  const _FinanceMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w800, color: color),
            ),
            Text(
              label,
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 8, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _TenantPaymentCard extends StatelessWidget {
  const _TenantPaymentCard({required this.tenant, this.onDocuments});

  final TenantRecord tenant;
  final VoidCallback? onDocuments;

  @override
  Widget build(BuildContext context) {
    final lease = tenant.lease;
    final expected = lease?.monthlyRent ?? tenant.apartment.rentAmount;
    final paid = tenant.paidThisMonth;
    final paidFull = expected > 0 && paid >= expected;
    final partial = paid > 0 && !paidFull;
    final overdue = lease != null && !paidFull && nextDueDate(lease).isBefore(DateTime.now());
    final color = paidFull
        ? AppColors.occupied
        : overdue
            ? AppColors.danger
            : partial
                ? AppColors.pending
                : AppColors.textMuted;
    final label = paidFull
        ? 'مسدد'
        : overdue
            ? 'متأخر'
            : partial
                ? 'جزئي'
                : 'بانتظار الدفع';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            AppAvatar(name: tenant.profile.displayName, imageUrl: tenant.profile.avatarUrl, size: 42),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tenant.profile.displayName,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${tenant.apartment.label} · ${formatMoney(expected, compact: true, country: tenant.apartment.country)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            if (onDocuments != null)
              IconButton(
                onPressed: onDocuments,
                tooltip: tr('المستمسكات وصور العقد'),
                icon: const Icon(
                  Icons.folder_copy_rounded,
                  size: 18,
                  color: AppColors.gold,
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusPill(label: label, color: color, compact: true),
                const SizedBox(height: 4),
                Text(
                  'سدد ${formatMoney(paid, compact: true, country: tenant.apartment.country)}',
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 9, fontWeight: FontWeight.w700, color: color),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
