import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/contact.dart';
import '../../core/utils/system_insets.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';
import '../shared/lease_documents_sheet.dart';
import 'add_tenant_screen.dart';
import 'pending_lease_card.dart';
import 'vacate_tenant_sheet.dart';
import '../../core/i18n/i18n.dart';

class ManagerTenantsScreen extends ConsumerStatefulWidget {
  const ManagerTenantsScreen({super.key, required this.profile});

  final AppProfile profile;

  @override
  ConsumerState<ManagerTenantsScreen> createState() => _ManagerTenantsScreenState();
}

class _ManagerTenantsScreenState extends ConsumerState<ManagerTenantsScreen> {
  bool _showArchive = false;

  Future<void> _refresh() async {
    ref.invalidate(managerSnapshotProvider);
    await ref.read(managerSnapshotProvider.future);
  }

  Future<void> _addTenant() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddTenantScreen(manager: widget.profile)),
    );
    ref.invalidate(managerSnapshotProvider);
    ref.invalidate(ownerSnapshotProvider);
  }

  @override
  Widget build(BuildContext context) {
    final snapshotAsync = ref.watch(managerSnapshotProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المستأجرون',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'العقود والتحصيل والتواصل',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
              ),
              IconButton(
                onPressed: _addTenant,
                icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.gold),
              ),
            ],
          ),
        ),
        Expanded(
          child: snapshotAsync.when(
            loading: () => const LoadingList(count: 4),
            error: (error, _) => ErrorView(message: friendlyError(error), onRetry: _refresh),
            data: (snapshot) {
              final paidTotal = snapshot.tenants.fold<double>(0, (sum, tenant) => sum + tenant.paidThisMonth);
              final archived = snapshot.archivedTenants;
              final archivedPaid = archived.fold<double>(0, (sum, tenant) => sum + tenant.paidTotal);
              return RefreshIndicator(
                color: AppColors.gold,
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
                  children: [
                    _ViewToggle(
                      showArchive: _showArchive,
                      activeCount: snapshot.tenants.length,
                      archivedCount: archived.length,
                      onChanged: (value) => setState(() => _showArchive = value),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_showArchive) ...[
                      GlassCard(
                        glowColor: AppColors.textMuted,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Expanded(child: _Summary(label: 'مؤرشفون', value: '${archived.length}', color: AppColors.textPrimary)),
                            Expanded(child: _Summary(label: 'إجمالي مدفوعاتهم', value: formatMoney(archivedPaid, compact: true), color: AppColors.occupied)),
                            Expanded(
                              child: _Summary(
                                label: 'آخر إخلاء',
                                value: archived.isEmpty || archived.first.moveOutDate == null
                                    ? '—'
                                    : formatDate(archived.first.moveOutDate!),
                                color: AppColors.gold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SectionHeader(
                        title: 'المستأجرون المؤرشفون',
                        subtitle: archived.isEmpty
                            ? 'سجل المستأجرين الذين غادروا'
                            : '${archived.length} سجل محفوظ بالكامل',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (archived.isEmpty)
                        const EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'الأرشيف فارغ',
                          message: 'عند إخلاء أي مستأجر سيظهر سجله هنا مع عقده ودفعاته ومستمسكاته.',
                        )
                      else
                        ...archived.map(
                          (tenant) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _ArchivedTenantCard(
                              record: tenant,
                              onTap: () => _showArchiveSheet(tenant),
                            ),
                          ),
                        ),
                    ] else ...[
                      GlassCard(
                        glowColor: AppColors.occupied,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Expanded(child: _Summary(label: 'مستأجرون', value: '${snapshot.tenants.length}', color: AppColors.textPrimary)),
                            Expanded(child: _Summary(label: 'محصّل هذا الشهر', value: formatMoney(paidTotal, compact: true), color: AppColors.occupied)),
                            Expanded(child: _Summary(label: 'طلبات ربط', value: '${snapshot.pendingLeases.length}', color: AppColors.pending)),
                          ],
                        ),
                      ),
                      if (snapshot.pendingLeases.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        SectionHeader(
                          title: 'طلبات ربط الشقق',
                          subtitle: '${snapshot.pendingLeases.length} طلب بانتظار الموافقة',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ...snapshot.pendingLeases.map(
                          (lease) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: PendingLeaseCard(
                              lease: lease,
                              manager: widget.profile,
                              onChanged: () => ref.invalidate(managerSnapshotProvider),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      SectionHeader(
                        title: 'المستأجرون النشطون',
                        subtitle: '${snapshot.tenants.length} مستأجر',
                        actionLabel: 'إضافة',
                        onAction: _addTenant,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (snapshot.tenants.isEmpty)
                        const EmptyState(
                          icon: Icons.people_outline_rounded,
                          title: 'لا يوجد مستأجرون بعد',
                          message: 'أضف مستأجراً من زر الإضافة في الأعلى أو من صفحة الشقق.',
                          actionLabel: 'إضافة مستأجر',
                        )
                      else
                        ...snapshot.tenants.map(
                          (tenant) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _TenantCard(
                              tenant: tenant,
                              onTap: () => _showTenantSheet(tenant),
                              onDocuments: tenant.lease == null
                                  ? null
                                  : () => LeaseDocumentsSheet.show(
                                        context,
                                        lease: tenant.lease!,
                                        tenantName: tenant.profile.displayName,
                                      ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showTenantSheet(TenantRecord tenant) async {
    final lease = tenant.lease;
    final expected = lease?.monthlyRent ?? tenant.apartment.rentAmount;
    final paidFull = expected > 0 && tenant.paidThisMonth >= expected;
    final due = lease == null ? null : nextDueDate(lease);
    final record = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: AppColors.navy800,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        padding: withSystemBottomInset(sheetContext, const EdgeInsets.all(AppSpacing.lg)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppAvatar(name: tenant.profile.displayName, imageUrl: tenant.profile.avatarUrl, size: 50, showRing: true),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tenant.profile.displayName,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          prettyPhone(tenant.profile.phoneNumber),
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(
                    label: paidFull ? 'مسدد' : 'غير مسدد',
                    color: paidFull ? AppColors.occupied : AppColors.pending,
                    compact: true,
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),
              InfoRow(icon: Icons.domain_rounded, label: 'الشقة', value: tenant.apartment.label),
              InfoRow(
                icon: Icons.payments_rounded,
                label: 'الإيجار الشهري',
                value: formatMoney(expected, withCurrency: true, country: tenant.apartment.country),
                valueColor: AppColors.gold,
              ),
              InfoRow(
                icon: Icons.savings_rounded,
                label: 'المدفوع هذا الشهر',
                value: formatMoney(tenant.paidThisMonth, withCurrency: true),
                valueColor: paidFull ? AppColors.occupied : AppColors.pending,
              ),
              if (lease != null) ...[
                InfoRow(icon: Icons.calendar_today_rounded, label: 'بداية العقد', value: formatDate(lease.startDate)),
                InfoRow(icon: Icons.event_available_rounded, label: 'نهاية العقد', value: formatDate(lease.endDate)),
                if (due != null)
                  InfoRow(
                    icon: Icons.alarm_rounded,
                    label: 'الاستحقاق القادم',
                    value: '${formatDate(due)} · ${formatDaysLeft(daysUntil(due))}',
                    valueColor: daysUntil(due) <= 7 ? AppColors.pending : AppColors.textPrimary,
                  ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => LeaseDocumentsSheet.show(
                    context,
                    lease: lease,
                    tenantName: tenant.profile.displayName,
                  ),
                  icon: const Icon(Icons.folder_copy_rounded, size: 18),
                  label: const Text('المستمسكات وصور العقد'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    minimumSize: const Size.fromHeight(44),
                    side: BorderSide(
                      color: AppColors.gold.withValues(alpha: .35),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              contactActions(
                context: context,
                phone: tenant.profile.phoneNumber,
                message: 'مرحباً ${tenant.profile.displayName}، بخصوص إيجار ${tenant.apartment.label}',
                color: AppColors.occupied,
              ),
              const SizedBox(height: AppSpacing.md),
              GoldButton(
                label: 'تسجيل دفعة إيجار',
                icon: Icons.receipt_long_rounded,
                onPressed: () => Navigator.pop(sheetContext, 'payment'),
              ),
              if (lease != null) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, 'vacate'),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('إخلاء الشقة وأرشفة المستأجر'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    minimumSize: const Size.fromHeight(44),
                    side: BorderSide(
                      color: AppColors.danger.withValues(alpha: .45),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (record == 'payment' && mounted) {
      await _recordPayment(tenant, expected);
    } else if (record == 'vacate' && mounted) {
      await _vacate(tenant);
    }
  }

  Future<void> _vacate(TenantRecord tenant) async {
    final saved = await showVacateTenantSheet(
      context: context,
      repository: ref.read(repositoryProvider),
      tenant: tenant,
    );
    if (!saved || !mounted) return;
    ref.invalidate(managerSnapshotProvider);
    ref.invalidate(managerAccountingProvider);
    ref.invalidate(ownerSnapshotProvider);
    ref.invalidate(ownerDashboardProvider);
    ref.invalidate(tenantSnapshotProvider);
    showSuccess(context, 'تم إخلاء الشقة وتحويلها إلى فارغة، وحُفظ سجل المستأجر');
  }

  Future<void> _showArchiveSheet(ArchivedTenantRecord record) async {
    final lease = record.lease;
    final recentPayments = record.payments.take(5).toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: AppColors.navy800,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        padding: withSystemBottomInset(sheetContext, const EdgeInsets.all(AppSpacing.lg)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppAvatar(name: record.profile.displayName, imageUrl: record.profile.avatarUrl, size: 50, showRing: true),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.profile.displayName,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          prettyPhone(record.profile.phoneNumber),
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const StatusPill(label: 'مؤرشف', color: AppColors.textMuted, compact: true),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),
              InfoRow(icon: Icons.domain_rounded, label: 'الشقة', value: record.apartment.label),
              InfoRow(
                icon: Icons.logout_rounded,
                label: 'تاريخ الإخلاء',
                value: record.moveOutDate == null ? 'غير محدد' : formatDate(record.moveOutDate!),
                valueColor: AppColors.danger,
              ),
              if (lease != null) ...[
                InfoRow(icon: Icons.calendar_today_rounded, label: 'بداية العقد', value: formatDate(lease.startDate)),
                InfoRow(icon: Icons.event_available_rounded, label: 'نهاية العقد', value: formatDate(lease.endDate)),
                InfoRow(
                  icon: Icons.payments_rounded,
                  label: 'الإيجار الشهري',
                  value: formatMoney(lease.monthlyRent, withCurrency: true),
                  valueColor: AppColors.gold,
                ),
              ],
              InfoRow(
                icon: Icons.savings_rounded,
                label: 'إجمالي المدفوعات',
                value: formatMoney(record.paidTotal, withCurrency: true),
                valueColor: AppColors.occupied,
              ),
              InfoRow(
                icon: Icons.receipt_long_rounded,
                label: 'عدد الدفعات',
                value: '${record.payments.length}',
              ),
              if (lease?.notes != null && lease!.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'ملاحظات العقد والأرشيف',
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  lease.notes!,
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                ),
              ],
              if (recentPayments.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                const Divider(),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'آخر الدفعات',
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...recentPayments.map(
                  (payment) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.occupied),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${formatDate(payment.paymentDate)} · ${payment.methodLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textMuted),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          formatMoney(payment.amount, withCurrency: true),
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.occupied,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (lease != null) ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => LeaseDocumentsSheet.show(
                    context,
                    lease: lease,
                    tenantName: record.profile.displayName,
                  ),
                  icon: const Icon(Icons.folder_copy_rounded, size: 18),
                  label: const Text('المستمسكات وصور العقد'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    minimumSize: const Size.fromHeight(44),
                    side: BorderSide(color: AppColors.gold.withValues(alpha: .35)),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              contactActions(
                context: context,
                phone: record.profile.phoneNumber,
                message: 'مرحباً ${record.profile.displayName}، بخصوص سجل إيجار ${record.apartment.label}',
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _recordPayment(TenantRecord tenant, double expected) async {
    final amountController = TextEditingController(text: expected.toStringAsFixed(0));
    final receiptController = TextEditingController();
    final notesController = TextEditingController();
    var method = 'cash';
    var date = DateTime.now();
    var loading = false;
    String? error;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final keyboard = MediaQuery.viewInsetsOf(context).bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: keyboard),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.navy800,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
                ),
                padding: withSystemBottomInset(sheetContext, const EdgeInsets.all(AppSpacing.lg)),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt_long_rounded, color: AppColors.occupied),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'تسجيل دفعة — ${tenant.profile.displayName}',
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${tenant.apartment.label} · الإيجار ${formatMoney(expected, withCurrency: true, country: tenant.apartment.country)}',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.occupied),
                        decoration: InputDecoration(
                          labelText: I18n.isEnglish
                              ? 'Amount received (${tenant.apartment.country.currencyCode})'
                              : 'المبلغ المستلم (${tenant.apartment.country.currencyCode})',
                          prefixIcon: Icon(Icons.payments_rounded),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<String>(
                        value: method,
                        dropdownColor: AppColors.navy700,
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: tr('طريقة الدفع'),
                          prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('نقداً')),
                          DropdownMenuItem(value: 'transfer', child: Text('تحويل بنكي')),
                          DropdownMenuItem(value: 'card', child: Text('بطاقة')),
                          DropdownMenuItem(value: 'cheque', child: Text('صك')),
                        ],
                        onChanged: (value) => setSheetState(() => method = value ?? 'cash'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 1)),
                            locale: Locale(I18n.language.name),
                          );
                          if (picked != null) setSheetState(() => date = picked);
                        },
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.navy700.withValues(alpha: .65),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: Colors.white.withValues(alpha: .08)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded, color: AppColors.gold, size: 20),
                              const SizedBox(width: AppSpacing.sm),
                              const Text(
                                'تاريخ الدفع',
                                style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const Spacer(),
                              Text(
                                formatDate(date),
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: receiptController,
                        style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: tr('رقم الوصل (اختياري)'),
                          prefixIcon: Icon(Icons.confirmation_number_rounded),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: tr('ملاحظات (اختياري)'),
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          error!,
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.danger),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      GoldButton(
                        label: 'حفظ الدفعة',
                        icon: Icons.check_circle_rounded,
                        loading: loading,
                        onPressed: () async {
                          final amount = double.tryParse(amountController.text);
                          if (amount == null || amount <= 0) {
                            setSheetState(() => error = 'أدخل مبلغاً صحيحاً');
                            return;
                          }
                          setSheetState(() {
                            loading = true;
                            error = null;
                          });
                          try {
                            await ref.read(repositoryProvider).recordPayment(
                                  tenantId: tenant.profile.id,
                                  amount: amount,
                                  method: method,
                                  date: date,
                                  receiptNumber: receiptController.text,
                                  notes: notesController.text,
                                );
                            ref.invalidate(managerSnapshotProvider);
                            ref.invalidate(ownerSnapshotProvider);
                            ref.invalidate(tenantSnapshotProvider);
                            if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                          } catch (errorObject) {
                            setSheetState(() {
                              loading = false;
                              error = friendlyError(errorObject);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    amountController.dispose();
    receiptController.dispose();
    notesController.dispose();
    if (saved == true && mounted) {
      showSuccess(context, 'تم تسجيل الدفعة بنجاح');
      _refresh();
    }
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.value, required this.color});

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
          style: TextStyle(fontFamily: 'Tajawal', fontSize: 17, fontWeight: FontWeight.w800, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 9, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _TenantCard extends StatelessWidget {
  const _TenantCard({required this.tenant, required this.onTap, this.onDocuments});

  final TenantRecord tenant;
  final VoidCallback onTap;
  final VoidCallback? onDocuments;

  @override
  Widget build(BuildContext context) {
    final lease = tenant.lease;
    final expected = lease?.monthlyRent ?? tenant.apartment.rentAmount;
    final paidFull = expected > 0 && tenant.paidThisMonth >= expected;
    final overdue = lease != null && !paidFull && nextDueDate(lease).isBefore(DateTime.now());
    final color = paidFull ? AppColors.occupied : overdue ? AppColors.danger : AppColors.pending;
    final label = paidFull ? 'مسدد' : overdue ? 'متأخر' : 'غير مسدد';
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          AppAvatar(name: tenant.profile.displayName, imageUrl: tenant.profile.avatarUrl, size: 46),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
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
                    ),
                    StatusPill(label: label, color: color, compact: true),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${tenant.apartment.label} · ${prettyPhone(tenant.profile.phoneNumber)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      formatMoney(expected, withCurrency: true, country: tenant.apartment.country),
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'سدد ${formatMoney(tenant.paidThisMonth, compact: true)}',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 9, color: color),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
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
          const Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.showArchive,
    required this.activeCount,
    required this.archivedCount,
    required this.onChanged,
  });

  final bool showArchive;
  final int activeCount;
  final int archivedCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.navy800.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tab(
              label: 'النشطون ($activeCount)',
              icon: Icons.people_alt_rounded,
              selected: !showArchive,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _tab(
              label: 'الأرشيف ($archivedCount)',
              icon: Icons.inventory_2_rounded,
              selected: showArchive,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.gold.withValues(alpha: .16) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.gold.withValues(alpha: .45) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: selected ? AppColors.gold : AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.gold : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchivedTenantCard extends StatelessWidget {
  const _ArchivedTenantCard({required this.record, required this.onTap});

  final ArchivedTenantRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          AppAvatar(name: record.profile.displayName, imageUrl: record.profile.avatarUrl, size: 46),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.profile.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const StatusPill(label: 'مؤرشف', color: AppColors.textMuted, compact: true),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${record.apartment.label} · ${prettyPhone(record.profile.phoneNumber)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 12, color: AppColors.danger.withValues(alpha: .8)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        record.moveOutDate == null
                            ? 'تاريخ الإخلاء غير محدد'
                            : 'خرج في ${formatDate(record.moveOutDate!)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'مدفوعات ${formatMoney(record.paidTotal, compact: true)}',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.occupied,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
