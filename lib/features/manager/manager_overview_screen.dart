import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';
import '../shared/building_details_screen.dart';
import '../shared/request_card.dart';
import '../shared/request_detail_screen.dart';
import 'add_tenant_screen.dart';
import 'pending_lease_card.dart';

class ManagerOverviewScreen extends ConsumerWidget {
  const ManagerOverviewScreen({
    super.key,
    required this.profile,
    required this.onNavigate,
  });

  final AppProfile profile;
  final ValueChanged<int> onNavigate;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(managerSnapshotProvider);
    await ref.read(managerSnapshotProvider.future);
  }

  String _scopeLabel(ManagerSnapshot snapshot) {
    final names = snapshot.portfolio.compounds
        .map((compound) => compound.name)
        .where((name) => name.trim().isNotEmpty)
        .toList();
    if (names.isEmpty) return 'لا يوجد عقار موكل لحسابك بعد';
    final shown = names.take(2).join(' · ');
    return names.length > 2 ? '$shown +${names.length - 2}' : 'مسؤول عن: $shown';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(managerSnapshotProvider);
    return snapshotAsync.when(
      loading: () => const LoadingList(count: 4),
      error: (error, _) => ErrorView(
        message: friendlyError(error),
        onRetry: () => ref.invalidate(managerSnapshotProvider),
      ),
      data: (snapshot) => RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
          children: [
            PremiumHeader(
              name: profile.displayName,
              roleLabel: 'مدير',
              subtitle: _scopeLabel(snapshot),
              avatarUrl: profile.avatarUrl,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'طلبات نشطة',
                    value: '${snapshot.activeRequests.length}',
                    icon: Icons.build_rounded,
                    color: AppColors.info,
                    compact: true,
                    caption: '${snapshot.urgentCount} عاجل',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: StatCard(
                    label: 'بانتظار المالك',
                    value: '${snapshot.awaitingApproval.length}',
                    icon: Icons.verified_user_rounded,
                    color: AppColors.gold,
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
                    label: 'جاهزة للتنفيذ',
                    value: '${snapshot.readyToExecute.length}',
                    icon: Icons.handyman_rounded,
                    color: AppColors.occupied,
                    compact: true,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: StatCard(
                    label: 'طلبات ربط',
                    value: '${snapshot.pendingLeases.length}',
                    icon: Icons.assignment_ind_rounded,
                    color: AppColors.pending,
                    compact: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _buildQuickActions(context, ref),
            if (snapshot.pendingLeases.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              SectionHeader(
                title: 'طلبات ربط الشقق',
                subtitle: '${snapshot.pendingLeases.length} طلب بانتظار قرارك',
              ),
              const SizedBox(height: AppSpacing.md),
              ...snapshot.pendingLeases.map(
                (lease) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: PendingLeaseCard(
                    lease: lease,
                    manager: profile,
                    onChanged: () => ref.invalidate(managerSnapshotProvider),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: 'طلبات الصيانة',
              subtitle: 'مرتبة حسب الأولوية',
              actionLabel: 'عرض الكل',
              onAction: () => onNavigate(1),
            ),
            const SizedBox(height: AppSpacing.md),
            if (snapshot.activeRequests.isEmpty)
              GlassCard(
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
                            'لا توجد طلبات نشطة',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'كل شيء تحت السيطرة.',
                            style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              ...snapshot.activeRequests.take(3).map(
                    (request) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: RequestCard(
                        request: request,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RequestDetailScreen(requestId: request.id, viewer: profile),
                            ),
                          );
                          ref.invalidate(managerSnapshotProvider);
                        },
                      ),
                    ),
                  ),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: 'العمارات',
              subtitle: '${snapshot.portfolio.buildingsCount} عمارة تحت إدارتك',
              actionLabel: 'العقارات',
              onAction: () => onNavigate(2),
            ),
            const SizedBox(height: AppSpacing.md),
            if (snapshot.portfolio.buildings.isEmpty)
              const EmptyState(
                icon: Icons.apartment_rounded,
                title: 'لا توجد عمارات موكلة إليك',
                message: 'تواصل مع مالك العقار لتخصيص العقارات إلى حسابك.',
              )
            else
              for (final compound in snapshot.portfolio.compounds)
                ...compound.buildings.map(
                  (building) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _BuildingRow(
                      building: building,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BuildingDetailsScreen(
                              viewer: profile,
                              compound: compound,
                              building: building,
                            ),
                          ),
                        );
                        ref.invalidate(managerSnapshotProvider);
                      },
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.person_add_alt_1_rounded,
            label: 'إضافة مستأجر',
            color: AppColors.gold,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AddTenantScreen(manager: profile)),
              );
              ref.invalidate(managerSnapshotProvider);
              ref.invalidate(ownerSnapshotProvider);
            },
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _QuickAction(
            icon: Icons.account_balance_wallet_rounded,
            label: 'الحسابات',
            color: AppColors.occupied,
            onTap: () => onNavigate(4),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _QuickAction(
            icon: Icons.build_rounded,
            label: 'الطلبات',
            color: AppColors.info,
            onTap: () => onNavigate(1),
          ),
        ),
      ],
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
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildingRow extends StatelessWidget {
  const _BuildingRow({required this.building, required this.onTap});

  final Building building;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final apartments = building.apartments;
    final occupied = apartments.where((a) => a.status == ApartmentStatus.occupied).length;
    final vacant = apartments.where((a) => a.status == ApartmentStatus.vacant).length;
    final rate = apartments.isEmpty ? 0.0 : occupied / apartments.length;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.apartment_rounded, color: AppColors.info, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  building.name,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                OccupancyBar(rate: rate, showLabel: false, height: 5, color: AppColors.info),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$occupied/${apartments.length}',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                vacant > 0 ? '$vacant فارغة' : 'مكتملة',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 9,
                  color: vacant > 0 ? AppColors.vacant : AppColors.occupied,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
