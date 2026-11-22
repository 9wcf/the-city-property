import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../shared/building_details_screen.dart';
import '../shared/request_card.dart';
import '../shared/request_detail_screen.dart';
import 'web/magic_apartments_dialog.dart';

class OwnerOverviewScreen extends ConsumerWidget {
  const OwnerOverviewScreen({
    super.key,
    required this.profile,
    required this.onNavigate,
  });

  final AppProfile profile;
  final ValueChanged<int> onNavigate;

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
            PremiumHeader(
              name: profile.displayName,
              roleLabel: 'مالك',
              subtitle: 'لوحة المالك التنفيذية',
              avatarUrl: profile.avatarUrl,
            ),
            const SizedBox(height: AppSpacing.lg),
            const SizedBox(height: AppSpacing.md),
            _buildPortfolioHero(view, country),
            if (view.overdueTenants > 0) ...[
              const SizedBox(height: AppSpacing.md),
              _buildOverdueBanner(view, () => onNavigate(3)),
            ],
            const SizedBox(height: AppSpacing.md),
            _MagicBanner(
              onTap: () => MagicApartmentsDialog.show(context),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildQuickActions(),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: 'طلبات بانتظار موافقتك',
              subtitle: '${view.pendingApprovals.length} طلب يحتاج قراراً',
              actionLabel: view.pendingApprovals.isEmpty ? null : 'عرض الكل',
              onAction: () => onNavigate(2),
            ),
            const SizedBox(height: AppSpacing.md),
            if (view.pendingApprovals.isEmpty)
              _buildAllClear()
            else
              ...view.pendingApprovals.take(2).map(
                    (request) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: RequestCard(
                        request: request,
                        onTap: () => _openRequest(context, ref, request),
                      ),
                    ),
                  ),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: 'حالة العمارات',
              subtitle: 'عمارات ${country.nameAr} · نظرة سريعة على الإشغال',
              actionLabel: 'العقارات',
              onAction: () => onNavigate(1),
            ),
            const SizedBox(height: AppSpacing.md),
            if (view.portfolio.buildings.isEmpty)
              const EmptyState(
                icon: Icons.domain_disabled_rounded,
                title: 'لا توجد عمارات مسجلة',
                message: 'أضف العقارات والعمارات من قاعدة البيانات لتظهر هنا.',
              )
            else
              for (final compound in view.portfolio.compounds)
                ...compound.buildings.map(
                  (building) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _BuildingStatusCard(
                      building: building,
                      onTap: () => _openBuilding(context, ref, compound, building),
                    ),
                  ),
                ),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: 'آخر الدفعات',
              subtitle:
                  'المستلم هذا الشهر ${formatMoney(view.collectedThisMonth, withCurrency: true, country: country)}',
              actionLabel: 'المالية',
              onAction: () => onNavigate(3),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildRecentPayments(view, country),
          ],
        ),
      );
      },
    );
  }

  Widget _buildPortfolioHero(OwnerCountryView view, AppCountry country) {
    final portfolio = view.portfolio;
    return GlassCard(
      glowColor: AppColors.gold,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Row(
            children: [
              OccupancyRing(rate: portfolio.occupancyRate, size: 108, label: 'نسبة الإشغال'),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الإيراد الشهري المتوقع',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatMoney(portfolio.monthlyExpected,
                          withCurrency: true, country: country),
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const Icon(Icons.savings_rounded, size: 14, color: AppColors.occupied),
                        const SizedBox(width: 4),
                        Text(
                          'محصّل ${formatMoney(view.collectedThisMonth, compact: true, country: country)}',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.occupied,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.trending_up_rounded, size: 14, color: AppColors.info),
                        const SizedBox(width: 4),
                        Text(
                          'نسبة التحصيل ${percent(view.collectionRate)}',
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: view.collectionRate,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: .07),
              valueColor: const AlwaysStoppedAnimation(AppColors.occupied),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _MetricBox(label: 'العقارات', value: '${portfolio.compounds.length}', icon: Icons.location_city_rounded),
              const SizedBox(width: AppSpacing.sm),
              _MetricBox(label: 'العمارات', value: '${portfolio.buildingsCount}', icon: Icons.apartment_rounded),
              const SizedBox(width: AppSpacing.sm),
              _MetricBox(label: 'الشقق', value: '${portfolio.total}', icon: Icons.meeting_room_rounded),
              const SizedBox(width: AppSpacing.sm),
              _MetricBox(
                label: 'فارغة',
                value: '${portfolio.vacant}',
                icon: Icons.no_meeting_room_rounded,
                color: AppColors.vacant,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverdueBanner(OwnerCountryView view, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.danger.withValues(alpha: .35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '${view.overdueTenants} مستأجر لم يسدد إيجار هذا الشهر بعد',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
            ),
            const Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: AppColors.danger),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        _QuickAction(
          icon: Icons.fact_check_rounded,
          label: 'الموافقات',
          color: AppColors.gold,
          onTap: () => onNavigate(2),
        ),
        const SizedBox(width: AppSpacing.sm),
        _QuickAction(
          icon: Icons.account_balance_wallet_rounded,
          label: 'المالية',
          color: AppColors.occupied,
          onTap: () => onNavigate(3),
        ),
        const SizedBox(width: AppSpacing.sm),
        _QuickAction(
          icon: Icons.domain_rounded,
          label: 'العقارات',
          color: AppColors.info,
          onTap: () => onNavigate(1),
        ),
      ],
    );
  }

  Widget _buildAllClear() {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.occupied.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.occupied, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'لا توجد موافقات معلقة',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'كل طلبات الصيانة تمت معالجتها.',
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPayments(OwnerCountryView view, AppCountry country) {
    if (view.payments.isEmpty) {
      return const GlassCard(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.receipt_long_rounded, color: AppColors.textMuted, size: 20),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'لا توجد دفعات مسجلة بعد. سجّل الدفعات من صفحة المستأجرين.',
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, height: 1.6, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      );
    }
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Column(
        children: view.payments.take(4).map((payment) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.occupied.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.check_rounded, color: AppColors.occupied, size: 18),
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
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${formatDate(payment.paymentDate)} · ${payment.methodLabel}',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 9, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatMoney(payment.amount, withCurrency: true, country: country),
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
    );
  }

  Future<void> _openRequest(BuildContext context, WidgetRef ref, MaintenanceRequest request) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RequestDetailScreen(requestId: request.id, viewer: profile),
      ),
    );
    ref.invalidate(ownerSnapshotProvider);
  }

  Future<void> _openBuilding(
    BuildContext context,
    WidgetRef ref,
    Compound compound,
    Building building,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BuildingDetailsScreen(
          viewer: profile,
          compound: compound,
          building: building,
        ),
      ),
    );
    ref.invalidate(ownerSnapshotProvider);
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.textPrimary,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: .06)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 15, color: color == AppColors.textPrimary ? AppColors.textMuted : color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 15, fontWeight: FontWeight.w800, color: color),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 8, color: AppColors.textMuted),
            ),
          ],
        ),
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
    return Expanded(
      child: InkWell(
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
      ),
    );
  }
}

class _BuildingStatusCard extends StatelessWidget {
  const _BuildingStatusCard({required this.building, required this.onTap});

  final Building building;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final apartments = building.apartments;
    final occupied = apartments.where((a) => a.status == ApartmentStatus.occupied).length;
    final rate = apartments.isEmpty ? 0.0 : occupied / apartments.length;
    final full = apartments.isNotEmpty && occupied == apartments.length;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: full ? AppColors.occupied.withValues(alpha: .28) : null,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (full ? AppColors.occupied : AppColors.gold).withValues(alpha: .11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              full ? Icons.workspace_premium_rounded : Icons.apartment_rounded,
              color: full ? AppColors.occupied : AppColors.gold,
              size: 21,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        building.name,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (full)
                      const StatusPill(label: 'مكتملة', color: AppColors.occupied, compact: true)
                    else
                      Text(
                        percent(rate),
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.gold,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                OccupancyBar(rate: rate, showLabel: false, height: 5, color: full ? AppColors.occupied : AppColors.gold),
                const SizedBox(height: 4),
                Text(
                  '$occupied من ${apartments.length} شقة مؤجرة',
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 9, color: AppColors.textMuted),
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

class _MagicBanner extends StatelessWidget {
  const _MagicBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: .30),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.navy900.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      size: 22, color: AppColors.navy900),
                ),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الزر السحري',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'كل الشقق المؤجرة والفارغة · المستأجر · المتبقي من الإيجار',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 10,
                          height: 1.4,
                          color: Color(0xCC03101F),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 15, color: AppColors.navy900),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
