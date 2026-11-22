import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/utils/app_utils.dart';
import '../../../core/widgets/premium_widgets.dart';
import '../../../data/models.dart';
import 'web_ui.dart';

class TenantsSection extends ConsumerStatefulWidget {
  const TenantsSection({super.key});

  @override
  ConsumerState<TenantsSection> createState() => _TenantsSectionState();
}

class _TenantsSectionState extends ConsumerState<TenantsSection> {
  Future<void> _refresh() async {
    ref.invalidate(ownerSnapshotProvider);
    ref.invalidate(ownerDashboardProvider);
    await ref.read(ownerDashboardProvider.future);
  }

  Future<void> _deleteArchivedTenant(ArchivedTenantRecord record) async {
    final name = record.profile.displayName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المستأجر المؤرشف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('سيتم حذف «$name» نهائياً مع:'),
            const SizedBox(height: AppSpacing.sm),
            const Text('• عقد الإيجار وسجل الشقة'),
            Text(
                '• الدفعات (${record.paymentCount}) بإجمالي ${formatMoney(record.paidTotal, withCurrency: true, country: record.apartment.country)}'),
            const Text('• المستمسكات والإشعارات وحساب الدخول'),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'لا يمكن التراجع عن هذا الإجراء.',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.danger,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(repositoryProvider).deleteArchivedTenant(record.profile.id);
      ref.invalidate(ownerSnapshotProvider);
      ref.invalidate(ownerDashboardProvider);
      if (mounted) showSuccess(context, 'تم حذف $name نهائياً');
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
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
        final tenants = data.snapshot.tenants
            .where((tenant) => tenant.apartment.country == country)
            .toList();
        final archived = data.snapshot.archivedTenants
            .where((record) => record.apartment.country == country)
            .toList();
        final monthlyRent = tenants.fold<double>(
          0,
          (sum, tenant) => sum + (tenant.lease?.monthlyRent ?? 0),
        );
        final archivedPaid = archived.fold<double>(
          0,
          (sum, record) => sum + record.paidTotal,
        );
        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              WebPageHeader(
                title: 'المستأجرون',
                subtitle:
                    'المستأجرون الحاليون وسجل المستأجرين المؤرشفين في ${country.name(english: I18n.isEnglish)} — الحذف النهائي متاح للمالك فقط',
                actions: [
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('تحديث'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              WebKpiGrid(
                children: [
                  WebKpiCard(
                    label: 'المستأجرون الحاليون',
                    value: '${tenants.length}',
                    icon: Icons.people_alt_rounded,
                    color: AppColors.occupied,
                  ),
                  WebKpiCard(
                    label: 'المستأجرون المؤرشفون',
                    value: '${archived.length}',
                    icon: Icons.inventory_2_outlined,
                    color: archived.isEmpty ? AppColors.textMuted : AppColors.gold,
                  ),
                  WebKpiCard(
                    label: 'الإيجار الشهري',
                    value: formatMoney(monthlyRent, withCurrency: true, country: country),
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.info,
                  ),
                  WebKpiCard(
                    label: 'مدفوعات الأرشيف',
                    value: formatMoney(archivedPaid, withCurrency: true, country: country),
                    icon: Icons.payments_rounded,
                    color: AppColors.gold,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              WebPanel(
                title: 'المستأجرون الحاليون',
                subtitle: '${tenants.length} مستأجر مرتبط بمحفظتك',
                child: WebTable(
                  minWidth: 760,
                  empty: const WebEmpty(
                    icon: Icons.people_outline_rounded,
                    title: 'لا يوجد مستأجرون حاليون',
                    message: 'سيظهر هنا كل مستأجر مرتبط بشقة داخل محفظتك.',
                  ),
                  columns: const [
                    WebTableColumn('المستأجر', flex: 3),
                    WebTableColumn('الشقة', flex: 3),
                    WebTableColumn('الإيجار الشهري', flex: 2),
                    WebTableColumn('نهاية العقد', flex: 2),
                    WebTableColumn('مدفوع هذا الشهر', flex: 2),
                  ],
                  rows: tenants
                      .map(
                        (tenant) => [
                          _TenantIdentity(profile: tenant.profile),
                          Text(
                            tenant.apartment.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11,
                              height: 1.4,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            tenant.lease == null
                                ? '—'
                                : formatMoney(tenant.lease!.monthlyRent, country: tenant.apartment.country,
                                    withCurrency: true),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            tenant.lease == null
                                ? '—'
                                : formatDate(tenant.lease!.endDate),
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            formatMoney(tenant.paidThisMonth, country: tenant.apartment.country,
                                withCurrency: true),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.occupied,
                            ),
                          ),
                        ],
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _ArchivedTenantsPanel(
                records: archived,
                onDelete: _deleteArchivedTenant,
              ),
              const SizedBox(height: AppSpacing.md),
              const _OwnerDeletionHint(),
            ],
          ),
        );
      },
    );
  }
}

class _TenantIdentity extends StatelessWidget {
  const _TenantIdentity({required this.profile});

  final AppProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppAvatar(name: profile.displayName, size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                profile.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                prettyPhone(profile.phoneNumber),
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArchivedTenantsPanel extends StatelessWidget {
  const _ArchivedTenantsPanel({required this.records, required this.onDelete});

  final List<ArchivedTenantRecord> records;
  final ValueChanged<ArchivedTenantRecord> onDelete;

  @override
  Widget build(BuildContext context) {
    return WebPanel(
      title: 'المستأجرون المؤرشفون',
      subtitle:
          '${records.length} سجل — الحذف النهائي متاح للمالك فقط ويشمل العقد والدفعات والمستمسكات',
      borderColor: AppColors.danger.withValues(alpha: .22),
      child: WebTable(
        minWidth: 760,
        empty: const WebEmpty(
          icon: Icons.inventory_2_outlined,
          title: 'لا يوجد مستأجرون مؤرشفون',
          message: 'سيظهر هنا كل مستأجر خرج من شقته وأرشف المدير سجله.',
        ),
        columns: const [
          WebTableColumn('المستأجر', flex: 3),
          WebTableColumn('الشقة', flex: 3),
          WebTableColumn('تاريخ الإخلاء', flex: 2),
          WebTableColumn('إجمالي المدفوعات', flex: 2),
          WebTableColumn('إجراءات', flex: 2, align: TextAlign.center),
        ],
        rows: records
            .map(
              (record) => [
                _TenantIdentity(profile: record.profile),
                Text(
                  record.apartment.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  record.moveOutDate == null
                      ? '—'
                      : formatDate(record.moveOutDate!),
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 10,
                    color: AppColors.danger,
                  ),
                ),
                Text(
                  formatMoney(record.paidTotal, withCurrency: true, country: record.apartment.country),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.occupied,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: WebRowAction(
                    icon: Icons.delete_forever_rounded,
                    tooltip: tr('حذف المؤرشف نهائياً'),
                    color: AppColors.danger,
                    onTap: () => onDelete(record),
                  ),
                ),
              ],
            )
            .toList(),
      ),
    );
  }
}

class _OwnerDeletionHint extends StatelessWidget {
  const _OwnerDeletionHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.danger.withValues(alpha: .18)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: AppColors.danger, size: 18),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'حذف المستأجر المؤرشف متاح لحساب المالك فقط ولا يظهر للمديرين. الحذف نهائي ويشمل العقد والدفعات والمستمسكات والإشعارات وحساب الدخول، ولا يمكن التراجع عنه.',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
