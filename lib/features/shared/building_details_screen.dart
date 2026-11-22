import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_utils.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';
import '../manager/add_tenant_screen.dart';
import 'apartment_details_screen.dart';

class BuildingDetailsScreen extends ConsumerStatefulWidget {
  const BuildingDetailsScreen({
    super.key,
    required this.viewer,
    required this.compound,
    required this.building,
  });

  final AppProfile viewer;
  final Compound compound;
  final Building building;

  @override
  ConsumerState<BuildingDetailsScreen> createState() => _BuildingDetailsScreenState();
}

class _BuildingDetailsScreenState extends ConsumerState<BuildingDetailsScreen> {
  late Building _building = widget.building;
  Portfolio? _portfolio;
  bool _loading = false;

  Future<Portfolio> _fetchPortfolio() async {
    final repo = ref.read(repositoryProvider);
    return widget.viewer.role == UserRole.owner
        ? repo.ownerPortfolio(widget.viewer.id)
        : repo.managerPortfolio(widget.viewer.id);
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final portfolio = await _fetchPortfolio();
      final compound = portfolio.compounds.where((c) => c.id == widget.compound.id).firstWhere(
            (c) => true,
            orElse: () => widget.compound,
          );
      final building = compound.buildings.where((b) => b.id == widget.building.id).firstWhere(
            (b) => true,
            orElse: () => widget.building,
          );
      if (!mounted) return;
      setState(() {
        _portfolio = portfolio;
        _building = building;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, friendlyError(error));
    }
  }

  Future<void> _ensurePortfolio() async {
    if (_portfolio != null) return;
    try {
      final portfolio = await _fetchPortfolio();
      if (!mounted) return;
      setState(() => _portfolio = portfolio);
    } catch (_) {
      // The add-tenant screen can load its own portfolio when needed.
    }
  }

  @override
  Widget build(BuildContext context) {
    final apartments = _building.apartments;
    final occupied = apartments.where((a) => a.status == ApartmentStatus.occupied).length;
    final vacant = apartments.where((a) => a.status == ApartmentStatus.vacant).length;
    final maintenance = apartments.where((a) => a.status == ApartmentStatus.maintenance).length;
    final rate = apartments.isEmpty ? 0.0 : occupied / apartments.length;
    final full = apartments.isNotEmpty && occupied == apartments.length;

    return PremiumScaffold(
      title: _building.name,
      actions: [
        IconButton(
          onPressed: _loading ? null : _reload,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                )
              : const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          GlassCard(
            glowColor: full ? AppColors.occupied : AppColors.gold,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Row(
                  children: [
                    OccupancyRing(
                      rate: rate,
                      size: 104,
                      color: full ? AppColors.occupied : AppColors.gold,
                      label: 'إشغال',
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.compound.name,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _building.name,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (_building.address != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              _building.address!,
                              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              StatusPill(label: '$occupied مؤجرة', color: AppColors.occupied, compact: true),
                              if (vacant > 0)
                                StatusPill(label: '$vacant فارغة', color: AppColors.vacant, compact: true),
                              if (maintenance > 0)
                                StatusPill(label: '$maintenance صيانة', color: AppColors.pending, compact: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    _Metric(label: 'الطوابق', value: '${_building.floors.length}'),
                    _Metric(label: 'الشقق', value: '${apartments.length}'),
                    _Metric(label: 'الإيراد الشهري', value: formatMoney(
                      apartments
                          .where((a) => a.status == ApartmentStatus.occupied)
                          .fold<double>(0, (sum, a) => sum + a.rentAmount),
                      compact: true,
                    ), color: AppColors.gold),
                  ],
                ),
              ],
            ),
          ),
          if (full) ...[
            const SizedBox(height: AppSpacing.md),
            _buildFullBanner(),
          ],
          if (vacant > 0) ...[
            const SizedBox(height: AppSpacing.md),
            _buildVacantSection(apartments.where((a) => a.status == ApartmentStatus.vacant).toList()),
          ],
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'الطوابق والشقق', subtitle: 'اضغط على أي شقة لعرض التفاصيل'),
          const SizedBox(height: AppSpacing.md),
          if (_building.floors.isEmpty)
            const EmptyState(icon: Icons.layers_clear_rounded, title: 'لا توجد طوابق مسجلة')
          else
            ..._building.floors.map((floor) => _buildFloor(floor)),
        ],
      ),
    );
  }

  Widget _buildFullBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppColors.occupied.withValues(alpha: .22),
            AppColors.gold.withValues(alpha: .12),
          ],
        ),
        border: Border.all(color: AppColors.occupied.withValues(alpha: .40)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.occupied.withValues(alpha: .16),
              border: Border.all(color: AppColors.occupied.withValues(alpha: .45)),
            ),
            child: const Icon(Icons.emoji_events_rounded, color: AppColors.occupied, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'العمارة مؤجرة بالكامل',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'كل الوحدات مشغولة — أداء استثماري ممتاز لهذا الشهر.',
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const StatusPill(label: '100%', color: AppColors.occupied, icon: Icons.stars_rounded, compact: true),
        ],
      ),
    );
  }

  Widget _buildVacantSection(List<Apartment> vacant) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderColor: AppColors.vacant.withValues(alpha: .25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'شقق فارغة',
            subtitle: '${vacant.length} وحدة جاهزة للتأجير',
          ),
          const SizedBox(height: AppSpacing.md),
          ...vacant.map(
            (apartment) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ApartmentListTile(
                apartment: apartment,
                onTap: () => _openApartment(apartment),
                trailing: widget.viewer.role == UserRole.manager
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: SoftButton(
                          label: 'تأجير',
                          icon: Icons.person_add_alt_1_rounded,
                          color: AppColors.gold,
                          expand: false,
                          height: 30,
                          onPressed: () => _addTenant(apartment),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloor(Floor floor) {
    final occupied = floor.apartments.where((a) => a.status == ApartmentStatus.occupied).length;
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  floor.apartments.isNotEmpty
                      ? floor.apartments.first.floorLabel
                      : 'الطابق ${floor.floorNumber}',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$occupied/${floor.apartments.length} مؤجرة',
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (floor.apartments.isEmpty)
            const Text(
              'لا توجد شقق في هذا الطابق.',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textMuted),
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: floor.apartments
                  .map(
                    (apartment) => ApartmentStatusChip(
                      apartment: apartment,
                      showRent: true,
                      onTap: () => _openApartment(apartment),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Future<void> _openApartment(Apartment apartment) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ApartmentDetailsScreen(
          apartmentId: apartment.id,
          viewer: widget.viewer,
          portfolio: _portfolio,
        ),
      ),
    );
    _reload();
  }

  Future<void> _addTenant(Apartment apartment) async {
    await _ensurePortfolio();
    if (!mounted) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddTenantScreen(
          manager: widget.viewer,
          portfolio: _portfolio,
          initialApartment: apartment,
        ),
      ),
    );
    if (result == true) {
      ref.invalidate(managerSnapshotProvider);
      ref.invalidate(ownerSnapshotProvider);
      _reload();
    }
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color = AppColors.textPrimary});

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
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 17, fontWeight: FontWeight.w800, color: color),
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
