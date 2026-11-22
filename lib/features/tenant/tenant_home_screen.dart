import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/i18n/app_country.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/contact.dart';
import '../../core/utils/system_insets.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';
import '../shared/request_card.dart';
import '../shared/request_detail_screen.dart';

class TenantHomeScreen extends ConsumerWidget {
  const TenantHomeScreen({
    super.key,
    required this.profile,
    required this.snapshot,
    required this.onNavigate,
    required this.onNewRequest,
  });

  final AppProfile profile;
  final TenantSnapshot snapshot;
  final ValueChanged<int> onNavigate;
  final VoidCallback onNewRequest;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(tenantSnapshotProvider);
    await ref.read(tenantSnapshotProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lease = snapshot.lease;
    final apartment = snapshot.apartment;
    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => _refresh(ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
        children: [
          PremiumHeader(
            name: profile.displayName,
            roleLabel: 'مستأجر',
            subtitle: apartment?.label ?? 'شقتك',
            avatarUrl: profile.avatarUrl,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (lease != null)
            RentCountdownCard(
              lease: lease,
              paidThisMonth: snapshot.paidThisMonth,
              country: apartment?.country ?? AppCountry.iq,
              onPay: () => onNavigate(2),
              onDetails: () => _showLease(context, lease),
            ),
          const SizedBox(height: AppSpacing.md),
          if (apartment != null) _buildApartmentCard(context, apartment),
          const SizedBox(height: AppSpacing.md),
          _buildQuickActions(context),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            title: 'طلبات الصيانة',
            subtitle: '${snapshot.requests.where((r) => r.isOpen).length} طلب مفتوح',
            actionLabel: snapshot.requests.isEmpty ? null : 'عرض الكل',
            onAction: () => onNavigate(1),
          ),
          const SizedBox(height: AppSpacing.md),
          if (snapshot.requests.isEmpty)
            GlassCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.handyman_rounded, color: AppColors.info, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'لا توجد طلبات صيانة',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'عند حاجتك لأي خدمة أرسل طلباً وسيتواصل معك المدير.',
                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, height: 1.5, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            ...snapshot.requests.take(3).map(
                  (request) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: RequestCard(
                      request: request,
                      showTenant: false,
                      onTap: () => _openRequest(context, ref, request),
                    ),
                  ),
                ),
          const SizedBox(height: AppSpacing.lg),
          _buildManagerCard(context),
          const SizedBox(height: AppSpacing.md),
          _buildLeaseSummary(context, lease, apartment?.country ?? AppCountry.iq),
        ],
      ),
    );
  }

  Widget _buildApartmentCard(BuildContext context, Apartment apartment) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.meeting_room_rounded, color: AppColors.gold, size: 23),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      apartment.displayName,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      [
                        if (apartment.compoundName != null) apartment.compoundName!,
                        if (apartment.buildingName != null) apartment.buildingName!,
                        if (apartment.floorLabel.isNotEmpty) apartment.floorLabel,
                      ].join(' · '),
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const StatusPill(label: 'مؤجرة', color: AppColors.occupied, compact: true),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _ApartmentMetric(label: 'الغرف', value: '${apartment.roomCount}'),
              _ApartmentMetric(
                label: 'المساحة',
                value: apartment.areaSqm == null ? '—' : '${apartment.areaSqm!.round()} م²',
              ),
              _ApartmentMetric(
                label: 'الطابق',
                value: apartment.floorLabel.isEmpty ? '—' : apartment.floorLabel,
              ),
              _ApartmentMetric(
                  label: 'الإيجار',
                  value: formatMoney(apartment.rentAmount,
                      compact: true, country: apartment.country),
                  color: AppColors.gold),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.add_circle_rounded,
            label: 'طلب صيانة',
            color: AppColors.gold,
            onTap: onNewRequest,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _QuickAction(
            icon: Icons.receipt_long_rounded,
            label: 'المدفوعات',
            color: AppColors.occupied,
            onTap: () => onNavigate(2),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _QuickAction(
            icon: Icons.support_agent_rounded,
            label: 'المدير',
            color: AppColors.info,
            onTap: () {
              if (snapshot.manager?.phoneNumber != null) {
                openPhoneCall(snapshot.manager!.phoneNumber);
              } else {
                showError(context, 'لم يتم تعيين مدير للعقار بعد');
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildManagerCard(BuildContext context) {
    final manager = snapshot.manager;
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'جهة الإدارة', subtitle: 'المسؤول عن مبناك'),
          const SizedBox(height: AppSpacing.md),
          if (manager == null)
            const Text(
              'لم يتم تعيين مدير عقارات لهذا العقار بعد.',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textMuted),
            )
          else ...[
            Row(
              children: [
                AppAvatar(name: manager.displayName, imageUrl: manager.avatarUrl, size: 46),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        manager.displayName,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        prettyPhone(manager.phoneNumber),
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            contactActions(
              context: context,
              phone: manager.phoneNumber,
              message: 'مرحباً، أنا ${profile.displayName} من ${snapshot.apartment?.label ?? ''}',
              color: AppColors.occupied,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLeaseSummary(BuildContext context, Lease? lease, AppCountry country) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'عقد الإيجار',
            subtitle: lease == null ? 'لا يوجد عقد' : 'ساري حتى ${formatDate(lease.endDate)}',
            actionLabel: lease == null ? null : 'التفاصيل',
            onAction: lease == null ? null : () => _showLease(context, lease),
          ),
          const SizedBox(height: AppSpacing.md),
          if (lease == null)
            const Text(
              'لم يتم ربط عقد بشقتك بعد.',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textMuted),
            )
          else ...[
            InfoRow(icon: Icons.calendar_today_rounded, label: 'بداية العقد', value: formatDate(lease.startDate)),
            InfoRow(icon: Icons.event_available_rounded, label: 'نهاية العقد', value: formatDate(lease.endDate)),
            InfoRow(
              icon: Icons.payments_rounded,
              label: 'الإيجار الشهري',
              value: formatMoney(lease.monthlyRent,
                  withCurrency: true, country: country),
              valueColor: AppColors.gold,
            ),
            InfoRow(
              icon: Icons.alarm_rounded,
              label: 'الاستحقاق القادم',
              value: formatDaysLeft(daysUntil(nextDueDate(lease))),
              valueColor: daysUntil(nextDueDate(lease)) <= 7 ? AppColors.pending : AppColors.textPrimary,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openRequest(BuildContext context, WidgetRef ref, MaintenanceRequest request) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RequestDetailScreen(
          requestId: request.id,
          viewer: profile,
          contact: snapshot.manager,
        ),
      ),
    );
    ref.invalidate(tenantSnapshotProvider);
  }

  void _showLease(BuildContext context, Lease lease) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.navy800,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        padding: withSystemBottomInset(context, const EdgeInsets.all(AppSpacing.lg)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.description_rounded, color: AppColors.gold),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text(
                      'تفاصيل عقد الإيجار',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              InfoRow(icon: Icons.meeting_room_rounded, label: 'الشقة', value: lease.apartmentLabel ?? '—'),
              InfoRow(icon: Icons.calendar_today_rounded, label: 'بداية العقد', value: formatDate(lease.startDate)),
              InfoRow(icon: Icons.event_available_rounded, label: 'نهاية العقد', value: formatDate(lease.endDate)),
              InfoRow(
                icon: Icons.payments_rounded,
                label: 'الإيجار الشهري',
                value: formatMoney(lease.monthlyRent,
                    withCurrency: true,
                    country: snapshot.apartment?.country ?? AppCountry.iq),
                valueColor: AppColors.gold,
              ),
              InfoRow(
                icon: Icons.savings_rounded,
                label: 'التأمين',
                value: formatMoney(lease.depositAmount,
                    withCurrency: true,
                    country: snapshot.apartment?.country ?? AppCountry.iq),
              ),
              InfoRow(icon: Icons.verified_rounded, label: 'الحالة', value: lease.isActive ? 'نشط' : lease.status),
              if (lease.terms != null) InfoRow(icon: Icons.gavel_rounded, label: 'الشروط', value: lease.terms!),
              if (lease.notes != null) InfoRow(icon: Icons.notes_rounded, label: 'ملاحظات', value: lease.notes!),
              const SizedBox(height: AppSpacing.lg),
              GoldButton(
                label: 'إغلاق',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApartmentMetric extends StatelessWidget {
  const _ApartmentMetric({required this.label, required this.value, this.color = AppColors.textPrimary});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 9, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: .22)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
