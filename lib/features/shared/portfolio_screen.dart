import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_utils.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import 'building_details_screen.dart';
import '../../core/i18n/i18n.dart';

class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({
    super.key,
    required this.viewer,
    this.initialPortfolio,
  });

  final AppProfile viewer;
  final Portfolio? initialPortfolio;

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  Portfolio? _portfolio;
  bool _loading = true;
  String? _error;
  String _query = '';
  final Map<String, List<CompoundManager>> _managers = {};

  @override
  void initState() {
    super.initState();
    _portfolio = widget.initialPortfolio;
    _loading = _portfolio == null;
    if (_portfolio == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(repositoryProvider);
      final portfolio = widget.viewer.role == UserRole.owner
          ? await repo.ownerPortfolio(widget.viewer.id)
          : await repo.managerPortfolio(widget.viewer.id);
      if (!mounted) return;
      setState(() {
        _portfolio = portfolio;
        _loading = false;
      });
      if (widget.viewer.role == UserRole.owner) {
        await _loadManagers(portfolio);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(error);
        _loading = false;
      });
    }
  }

  Future<void> _loadManagers(Portfolio portfolio) async {
    final repo = ref.read(repositoryProvider);
    final entries = await Future.wait(portfolio.compounds.map((compound) async {
      try {
        return MapEntry(compound.id, await repo.managersForCompound(compound.id));
      } catch (_) {
        return MapEntry(compound.id, const <CompoundManager>[]);
      }
    }));
    if (!mounted) return;
    setState(() {
      _managers
        ..clear()
        ..addEntries(entries);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingList(count: 4);
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    final portfolio = _portfolio!;
    final compounds = _query.isEmpty
        ? portfolio.compounds
        : portfolio.compounds.where((compound) {
            final query = _query.toLowerCase();
            if (compound.name.toLowerCase().contains(query)) return true;
            return compound.buildings.any((building) => building.name.toLowerCase().contains(query));
          }).toList();

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'المحفظة العقارية',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              StatusPill(
                label: '${portfolio.total} وحدة',
                color: AppColors.gold,
                icon: Icons.domain_rounded,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildSummary(portfolio),
          const SizedBox(height: AppSpacing.md),
          TextField(
            onChanged: (value) => setState(() => _query = value.trim()),
            style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: tr('ابحث في العقارات والعمارات…'),
              prefixIcon: Icon(Icons.search_rounded),
              contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (compounds.isEmpty)
            const EmptyState(
              icon: Icons.domain_disabled_rounded,
              title: 'لا توجد نتائج',
              message: 'لم يتم العثور على عقارات أو عمارات مطابقة.',
            )
          else
            for (final compound in compounds) ...[
              _buildCompound(compound),
              const SizedBox(height: AppSpacing.md),
            ],
        ],
      ),
    );
  }

  Widget _buildSummary(Portfolio portfolio) {
    return GlassCard(
      glowColor: AppColors.gold,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Row(
            children: [
              OccupancyRing(
                rate: portfolio.occupancyRate,
                size: 96,
                label: 'إشغال',
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _SummaryMetric(label: 'العقارات', value: '${portfolio.compounds.length}')),
                        Expanded(child: _SummaryMetric(label: 'العمارات', value: '${portfolio.buildingsCount}')),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(child: _SummaryMetric(label: 'مؤجرة', value: '${portfolio.occupied}', color: AppColors.occupied)),
                        Expanded(child: _SummaryMetric(label: 'فارغة', value: '${portfolio.vacant}', color: AppColors.vacant)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _LegendDot(color: AppColors.occupied, label: 'مؤجرة ${portfolio.occupied}'),
              const SizedBox(width: AppSpacing.md),
              _LegendDot(color: AppColors.vacant, label: 'فارغة ${portfolio.vacant}'),
              const SizedBox(width: AppSpacing.md),
              _LegendDot(color: AppColors.pending, label: 'صيانة ${portfolio.maintenance}'),
              const Spacer(),
              Text(
                'الإيراد ${formatMoney(portfolio.monthlyExpected, compact: true)}',
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.gold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompound(Compound compound) {
    final apartments = compound.apartments;
    final occupied = apartments.where((a) => a.status == ApartmentStatus.occupied).length;
    final rate = apartments.isEmpty ? 0.0 : occupied / apartments.length;
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.location_city_rounded, color: AppColors.gold, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      compound.name,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (compound.location != null)
                      Text(
                        compound.location!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
                      ),
                  ],
                ),
              ),
              Text(
                percent(rate),
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          OccupancyBar(rate: rate, showLabel: false),
          const SizedBox(height: AppSpacing.md),
          if (compound.buildings.isEmpty)
            const Text(
              'لا توجد عمارات مضافة لهذا العقار.',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textMuted),
            )
          else
            ...compound.buildings.map(
              (building) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _BuildingTile(
                  building: building,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BuildingDetailsScreen(
                        viewer: widget.viewer,
                        compound: compound,
                        building: building,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (widget.viewer.role == UserRole.owner) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildManagersTile(compound),
          ],
        ],
      ),
    );
  }

  Widget _buildManagersTile(Compound compound) {
    final managers = _managers[compound.id] ?? const <CompoundManager>[];
    final assigned = managers.isNotEmpty;
    final color = assigned ? AppColors.occupied : AppColors.pending;
    return InkWell(
      onTap: () => _openManagersDialog(compound),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: .28)),
        ),
        child: Row(
          children: [
            Icon(Icons.support_agent_rounded, color: color, size: 19),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assigned ? 'مديرو العقار' : 'لا يوجد مدير معيّن',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    assigned
                        ? managers.map((m) => m.fullName).join(' · ')
                        : 'طلبات ربط الشقق في هذا العقار لن تصل لأحد — عيّن مديراً',
                    maxLines: 2,
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
            if (assigned)
              StatusPill(label: '${managers.length}', color: color, compact: true),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Future<void> _openManagersDialog(Compound compound) async {
    final updated = await showDialog<List<CompoundManager>>(
      context: context,
      builder: (context) => _CompoundManagersDialog(
        compoundId: compound.id,
        compoundName: compound.name,
        initial: _managers[compound.id] ?? const <CompoundManager>[],
      ),
    );
    if (updated != null && mounted) {
      setState(() => _managers[compound.id] = updated);
    }
  }
}

class _CompoundManagersDialog extends ConsumerStatefulWidget {
  const _CompoundManagersDialog({
    required this.compoundId,
    required this.compoundName,
    required this.initial,
  });

  final String compoundId;
  final String compoundName;
  final List<CompoundManager> initial;

  @override
  ConsumerState<_CompoundManagersDialog> createState() => _CompoundManagersDialogState();
}

class _CompoundManagersDialogState extends ConsumerState<_CompoundManagersDialog> {
  late List<CompoundManager> _managers = List.of(widget.initial);
  final _phoneController = TextEditingController();
  bool _assigning = false;
  String? _removingId;
  bool _changed = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _assign() async {
    final phone = _phoneController.text.trim();
    if (phone.replaceAll(RegExp(r'\D'), '').length < 10) {
      showError(context, 'أدخل رقم هاتف المدير بشكل صحيح');
      return;
    }
    setState(() => _assigning = true);
    try {
      await ref.read(repositoryProvider).assignManager(
            compoundId: widget.compoundId,
            phone: phone,
          );
      _phoneController.clear();
      await _reload();
      _changed = true;
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  Future<void> _reload() async {
    try {
      final managers = await ref
          .read(repositoryProvider)
          .managersForCompound(widget.compoundId);
      if (mounted) setState(() => _managers = managers);
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    }
  }

  Future<void> _remove(CompoundManager manager) async {
    setState(() => _removingId = manager.managerId);
    try {
      await ref.read(repositoryProvider).removeManager(
            compoundId: widget.compoundId,
            managerId: manager.managerId,
          );
      await _reload();
      _changed = true;
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _removingId = null);
    }
  }

  void _close() => Navigator.of(context).pop(_changed ? _managers : null);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.navy800,
      title: Text(
        'مديرو ${widget.compoundName}',
        style: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'عيّن مديراً برقم هاتفه. يمكن تعيين أكثر من مدير للعقار نفسه، والمدير الواحد يمكن ربطه بعدة عقارات.',
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_managers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .03),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: Colors.white.withValues(alpha: .08)),
                  ),
                  child: const Text(
                    'لا يوجد مدير معيّن لهذا العقار بعد.',
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textSecondary),
                  ),
                )
              else
                for (final manager in _managers)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.gold.withValues(alpha: .20)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_rounded, color: AppColors.gold, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                manager.fullName,
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (manager.phoneNumber.isNotEmpty)
                                Text(
                                  manager.phoneNumber,
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 9.5,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_removingId == manager.managerId)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                          )
                        else
                          IconButton(
                            tooltip: tr('إزالة المدير'),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _remove(manager),
                            icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.danger, size: 19),
                          ),
                      ],
                    ),
                  ),
              const Divider(height: AppSpacing.lg),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(13),
                ],
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: tr('رقم هاتف المدير — مثال 07701234567'),
                  prefixIcon: Icon(Icons.phone_iphone_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              GoldButton(
                label: 'تعيين المدير',
                icon: Icons.person_add_alt_1_rounded,
                loading: _assigning,
                onPressed: _assigning ? null : _assign,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _close, child: const Text('تم')),
      ],
    );
  }
}

class _BuildingTile extends StatelessWidget {
  const _BuildingTile({required this.building, required this.onTap});

  final Building building;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final apartments = building.apartments;
    final occupied = apartments.where((a) => a.status == ApartmentStatus.occupied).length;
    final vacant = apartments.where((a) => a.status == ApartmentStatus.vacant).length;
    final rate = apartments.isEmpty ? 0.0 : occupied / apartments.length;
    final full = apartments.isNotEmpty && occupied == apartments.length;
    final color = full ? AppColors.occupied : AppColors.gold;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: full ? AppColors.occupied.withValues(alpha: .06) : Colors.white.withValues(alpha: .03),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: full ? AppColors.occupied.withValues(alpha: .30) : Colors.white.withValues(alpha: .07),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(full ? Icons.workspace_premium_rounded : Icons.apartment_rounded, color: color, size: 19),
                const SizedBox(width: AppSpacing.sm),
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
                  const StatusPill(
                    label: 'إشغال كامل',
                    color: AppColors.occupied,
                    icon: Icons.stars_rounded,
                    compact: true,
                  )
                else
                  Text(
                    '$occupied/${apartments.length}',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: AppColors.textMuted),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            OccupancyBar(rate: rate, showLabel: false, height: 5, color: color),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${building.floors.length} طوابق · ${apartments.length} شقة',
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 9, color: AppColors.textMuted),
                ),
                const Spacer(),
                if (vacant > 0)
                  Text(
                    '$vacant فارغة',
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.vacant),
                  )
                else
                  const Text(
                    'كل الشقق مؤجرة',
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.occupied),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value, this.color = AppColors.textPrimary});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontFamily: 'Tajawal', fontSize: 20, fontWeight: FontWeight.w800, color: color),
        ),
        Text(
          label,
          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 9, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
