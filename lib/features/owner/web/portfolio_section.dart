import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/i18n/app_country.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/premium_widgets.dart';
import '../../../data/models.dart';
import '../../../data/repositories.dart';
import 'web_ui.dart';

class PortfolioSection extends ConsumerStatefulWidget {
  const PortfolioSection({super.key});

  @override
  ConsumerState<PortfolioSection> createState() => _PortfolioSectionState();
}

class _PortfolioSectionState extends ConsumerState<PortfolioSection> {
  String? _selectedPropertyId;
  String? _selectedBuildingId;
  String _query = '';

  SupabaseRepository get _repository => ref.read(repositoryProvider);

  Future<void> _reload() async {
    ref.invalidate(ownerDashboardProvider);
    ref.invalidate(ownerSnapshotProvider);
    await ref.read(ownerDashboardProvider.future);
  }

  Future<void> _addProperty() async {
    final createdId = await showDialog<String>(
      context: context,
      builder: (_) => _PropertyDialog(
        repository: _repository,
        initialCountry: ref.read(ownerCountryProvider),
      ),
    );
    if (createdId != null && mounted) {
      setState(() {
        _selectedPropertyId = createdId;
        _selectedBuildingId = null;
      });
      await _reload();
      if (mounted) showSuccess(context, 'تمت إضافة العقار');
    }
  }

  Future<void> _editProperty(Compound property) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _PropertyDialog(
        repository: _repository,
        property: property,
      ),
    );
    if (changed == true && mounted) {
      await _reload();
      if (mounted) showSuccess(context, 'تم تحديث بيانات العقار');
    }
  }

  Future<void> _addBuilding(
    List<Compound> properties, {
    Compound? property,
  }) async {
    if (properties.isEmpty) {
      showError(context, 'أضف عقاراً أولاً ثم أضف العمارات داخله');
      return;
    }
    final createdFor = await showDialog<String>(
      context: context,
      builder: (_) => _BuildingDialog(
        repository: _repository,
        properties: properties,
        initialPropertyId: property?.id,
      ),
    );
    if (createdFor != null && mounted) {
      setState(() {
        _selectedPropertyId = createdFor;
        _selectedBuildingId = null;
      });
      await _reload();
      if (mounted) showSuccess(context, 'تمت إضافة العمارة وشققها');
    }
  }

  Future<void> _editBuilding(Compound property, Building building) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _BuildingDialog(
        repository: _repository,
        properties: [property],
        initialPropertyId: property.id,
        building: building,
      ),
    );
    if (changed == true && mounted) {
      await _reload();
      if (mounted) showSuccess(context, 'تم تحديث بيانات العمارة');
    }
  }

  Future<void> _addApartment(Building building) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _ApartmentDialog(
        repository: _repository,
        building: building,
      ),
    );
    if (created == true && mounted) {
      await _reload();
      if (mounted) showSuccess(context, 'تمت إضافة الشقة');
    }
  }

  Future<void> _editApartment(Apartment apartment) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ApartmentDialog(
        repository: _repository,
        building: null,
        apartment: apartment,
      ),
    );
    if (changed == true && mounted) {
      await _reload();
      if (mounted) showSuccess(context, 'تم تحديث الشقة');
    }
  }

  Future<void> _deleteApartment(Apartment apartment) async {
    final confirmed = await _confirm(
      title: 'حذف الشقة',
      message:
          'سيتم حذف ${apartment.displayName} نهائياً. لا يمكن التراجع.',
    );
    if (confirmed != true) return;
    try {
      await _repository.deleteApartment(apartment.id);
      await _reload();
      if (mounted) showSuccess(context, 'تم حذف الشقة');
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    }
  }

  Future<void> _deleteBuilding(Building building) async {
    final confirmed = await _confirm(
      title: 'حذف العمارة',
      message:
          'سيتم حذف العمارة «${building.name}» وكل طوابقها وشققها (${building.apartments.length} شقة). لا يمكن التراجع.',
    );
    if (confirmed != true) return;
    try {
      await _repository.deleteBuilding(building.id);
      if (_selectedBuildingId == building.id) {
        setState(() => _selectedBuildingId = null);
      }
      await _reload();
      if (mounted) showSuccess(context, 'تم حذف العمارة');
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    }
  }

  Future<bool?> _confirm({required String title, required String message}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  Compound? _findProperty(List<Compound> properties) {
    for (final property in properties) {
      if (property.id == _selectedPropertyId) return property;
    }
    return null;
  }

  Building? _findBuilding(Compound? property) {
    if (property == null) return null;
    for (final building in property.buildings) {
      if (building.id == _selectedBuildingId) return building;
    }
    return null;
  }

  List<Apartment> _filterApartments(List<Apartment> apartments) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return apartments;
    return apartments.where((apartment) {
      final floor = apartment.floorNumber;
      return apartment.unitNumber.toLowerCase().contains(query) ||
          apartment.label.toLowerCase().contains(query) ||
          (apartment.floorLabelText?.toLowerCase().contains(query) ?? false) ||
          (apartment.description?.toLowerCase().contains(query) ?? false) ||
          (floor != null && '$floor'.contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(ownerDashboardProvider);
    final country = ref.watch(ownerCountryProvider);

    return dashboard.when(
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
        final allCompounds = data.snapshot.portfolio.compounds;
        final properties = allCompounds
            .where((compound) => compound.country == country)
            .toList();
        final portfolio = Portfolio(properties);
        final buildings = portfolio.buildings;
        final apartments = portfolio.apartments;
        final countriesInView = properties.map((p) => p.country).toSet();
        final property = _findProperty(properties);
        final building = _findBuilding(property);
        final level = building != null
            ? 2
            : property != null
                ? 1
                : 0;
        final avgRent = apartments.isEmpty
            ? 0.0
            : apartments.fold<double>(0, (sum, a) => sum + a.rentAmount) /
                apartments.length;

        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () async {
            ref.invalidate(ownerDashboardProvider);
            try {
              await ref.read(ownerDashboardProvider.future);
            } catch (_) {
              // The error state is rendered by the provider watch above.
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WebPageHeader(
                  title: 'العقارات',
                  subtitle: 'العقارات ثم العمارات ثم الشقق',
                  actions: [
                    _ActionButton(
                      label: 'إضافة عقار',
                      icon: Icons.add_business_rounded,
                      filled: true,
                      onPressed: _addProperty,
                    ),
                    _ActionButton(
                      label: 'إضافة عمارة',
                      icon: Icons.apartment_rounded,
                      onPressed: () =>
                          _addBuilding(properties, property: property),
                    ),
                    _ActionButton(
                      label: 'تحديث',
                      icon: Icons.refresh_rounded,
                      onPressed: _reload,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                WebKpiGrid(
                  children: [
                    WebKpiCard(
                      label: 'العقارات',
                      value: '${properties.length}',
                      icon: Icons.location_city_rounded,
                      color: AppColors.gold,
                    ),
                    WebKpiCard(
                      label: 'العمارات',
                      value: '${buildings.length}',
                      icon: Icons.apartment_rounded,
                      color: AppColors.info,
                    ),
                    WebKpiCard(
                      label: 'مجموع الشقق',
                      value: '${apartments.length}',
                      icon: Icons.door_front_door_rounded,
                      color: AppColors.textPrimary,
                    ),
                    WebKpiCard(
                      label: 'شقق مؤجرة',
                      value:
                          '${apartments.where((a) => a.status == ApartmentStatus.occupied).length}',
                      icon: Icons.check_circle_rounded,
                      color: AppColors.occupied,
                    ),
                    WebKpiCard(
                      label: 'شقق فارغة',
                      value:
                          '${apartments.where((a) => a.status == ApartmentStatus.vacant).length}',
                      icon: Icons.home_outlined,
                      color: AppColors.pending,
                    ),
                    WebKpiCard(
                      label: 'متوسط الإيجار',
                      value: countriesInView.length > 1
                          ? '${countriesInView.length} دول'
                          : moneyText(avgRent,
                              country: countriesInView.isEmpty
                                  ? AppCountry.iq
                                  : countriesInView.first),
                      caption: countriesInView.length > 1
                          ? 'كل دولة بعملتها'
                          : null,
                      icon: Icons.payments_rounded,
                      color: AppColors.goldLight,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _WorkflowTabs(
                  current: level,
                  steps: [
                    _WorkflowStep(
                      label: 'العقارات',
                      caption: '${properties.length}',
                      enabled: true,
                      onTap: () => setState(() {
                        _selectedPropertyId = null;
                        _selectedBuildingId = null;
                        _query = '';
                      }),
                    ),
                    _WorkflowStep(
                      label: 'العمارات',
                      caption: property == null
                          ? 'اختر عقاراً'
                          : '${property.buildings.length}',
                      enabled: property != null,
                      onTap: () => setState(() {
                        _selectedBuildingId = null;
                        _query = '';
                      }),
                    ),
                    _WorkflowStep(
                      label: 'الشقق',
                      caption: building == null
                          ? 'اختر عمارة'
                          : '${building.apartments.length}',
                      enabled: building != null,
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (level == 0)
                  _PropertiesPanel(
                    properties: properties,
                    onOpen: (property) => setState(() {
                      _selectedPropertyId = property.id;
                      _selectedBuildingId = null;
                      _query = '';
                    }),
                    onEdit: _editProperty,
                    onAddBuilding: (property) =>
                        _addBuilding(properties, property: property),
                    onAddProperty: _addProperty,
                  )
                else if (level == 1)
                  _BuildingsPanel(
                    property: property!,
                    onOpen: (building) => setState(() {
                      _selectedBuildingId = building.id;
                      _query = '';
                    }),
                    onAddBuilding: () =>
                        _addBuilding(properties, property: property),
                    onEdit: (building) => _editBuilding(property, building),
                    onDelete: _deleteBuilding,
                    onBack: () => setState(() {
                      _selectedPropertyId = null;
                      _selectedBuildingId = null;
                    }),
                  )
                else
                  _ApartmentsPanel(
                    property: property!,
                    building: building!,
                    apartments: _filterApartments(building.apartments),
                    query: _query,
                    onQueryChanged: (value) => setState(() => _query = value),
                    onAdd: () => _addApartment(building),
                    onEdit: _editApartment,
                    onDelete: _deleteApartment,
                    onBackToBuildings: () =>
                        setState(() => _selectedBuildingId = null),
                    onBackToProperties: () => setState(() {
                      _selectedPropertyId = null;
                      _selectedBuildingId = null;
                    }),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Color statusColor(ApartmentStatus status) => switch (status) {
        ApartmentStatus.occupied => AppColors.occupied,
        ApartmentStatus.vacant => AppColors.pending,
        ApartmentStatus.maintenance => AppColors.info,
        ApartmentStatus.reserved => AppColors.reserved,
      };
}

class _WorkflowStep {
  const _WorkflowStep({
    required this.label,
    required this.caption,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String caption;
  final bool enabled;
  final VoidCallback onTap;
}

class _WorkflowTabs extends StatelessWidget {
  const _WorkflowTabs({required this.current, required this.steps});

  final int current;
  final List<_WorkflowStep> steps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 11,
                color: AppColors.textMuted.withValues(alpha: .6),
              ),
            ),
          Expanded(
            child: _WorkflowTab(
              index: i,
              step: steps[i],
              active: current == i,
              done: current > i,
            ),
          ),
        ],
      ],
    );
  }
}

class _WorkflowTab extends StatelessWidget {
  const _WorkflowTab({
    required this.index,
    required this.step,
    required this.active,
    required this.done,
  });

  final int index;
  final _WorkflowStep step;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? AppColors.gold
        : done
            ? AppColors.occupied
            : AppColors.textMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: step.enabled ? step.onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? AppColors.gold.withValues(alpha: .12)
                : Colors.white.withValues(alpha: .025),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: active
                  ? AppColors.gold.withValues(alpha: .45)
                  : Colors.white.withValues(alpha: .06),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: active ? .22 : .10),
                ),
                child: done
                    ? const Icon(Icons.check_rounded,
                        size: 14, color: AppColors.occupied)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: step.enabled
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                    Text(
                      step.caption,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _PropertiesPanel extends StatelessWidget {
  const _PropertiesPanel({
    required this.properties,
    required this.onOpen,
    required this.onEdit,
    required this.onAddBuilding,
    required this.onAddProperty,
  });

  final List<Compound> properties;
  final ValueChanged<Compound> onOpen;
  final ValueChanged<Compound> onEdit;
  final ValueChanged<Compound> onAddBuilding;
  final VoidCallback onAddProperty;

  @override
  Widget build(BuildContext context) {
    return WebPanel(
      title: 'العقارات',
      subtitle: 'اختر عقاراً لعرض عماراته، ومن العمارة تعرض الشقق',
      action: TextButton.icon(
        onPressed: onAddProperty,
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text('عقار'),
      ),
      child: properties.isEmpty
          ? const WebEmpty(
              title: 'لا توجد عقارات بعد',
              message: 'ابدأ بإضافة عقار، ثم أضف العمارات والشقق داخله.',
              icon: Icons.location_city_rounded,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final country in AppCountry.values)
                  if (properties.any((p) => p.country == country)) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                          top: AppSpacing.xs, bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          Text(country.flag,
                              style: const TextStyle(fontSize: 15)),
                          const SizedBox(width: 6),
                          Text(
                            '${country.name(english: I18n.isEnglish)} · ${country.currencyCode}',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.goldLight,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Divider(
                              color: Colors.white.withValues(alpha: .06),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${properties.where((p) => p.country == country).length} عقار',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 9.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [
                        for (final property in properties
                            .where((p) => p.country == country))
                          SizedBox(
                            width: 320,
                            child: _PropertyCard(
                              property: property,
                              onOpen: () => onOpen(property),
                              onEdit: () => onEdit(property),
                              onAddBuilding: () => onAddBuilding(property),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
              ],
            ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({
    required this.property,
    required this.onOpen,
    required this.onEdit,
    required this.onAddBuilding,
  });

  final Compound property;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onAddBuilding;

  @override
  Widget build(BuildContext context) {
    final units = property.apartments;
    final occupied =
        units.where((a) => a.status == ApartmentStatus.occupied).length;
    final rate = units.isEmpty ? 0.0 : occupied / units.length;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.navy800.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_city_rounded,
                    size: 20, color: AppColors.gold),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      property.location == null || property.location!.isEmpty
                          ? '${property.buildings.length} عمارة · ${units.length} شقة'
                          : '${property.buildings.length} عمارة · ${units.length} شقة · ${property.location}',
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
              WebPill(
                label:
                    '${property.country.flag} ${property.country.currencyCode}',
                color: AppColors.goldLight,
              ),
              const SizedBox(width: 6),
              WebRowAction(
                icon: Icons.edit_rounded,
                tooltip: tr('تعديل العقار'),
                onTap: onEdit,
              ),
              WebRowAction(
                icon: Icons.add_home_work_rounded,
                tooltip: tr('إضافة عمارة'),
                onTap: onAddBuilding,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: rate,
                    minHeight: 5,
                    backgroundColor: Colors.white.withValues(alpha: .06),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.gold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$occupied/${units.length} مؤجرة',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 9.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.apartment_rounded, size: 16),
            label: const Text('عرض العمارات'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold.withValues(alpha: .14),
              foregroundColor: AppColors.gold,
              padding: const EdgeInsets.symmetric(vertical: 10),
              textStyle: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BuildingsPanel extends StatelessWidget {
  const _BuildingsPanel({
    required this.property,
    required this.onOpen,
    required this.onAddBuilding,
    required this.onEdit,
    required this.onDelete,
    required this.onBack,
  });

  final Compound property;
  final ValueChanged<Building> onOpen;
  final VoidCallback onAddBuilding;
  final ValueChanged<Building> onEdit;
  final ValueChanged<Building> onDelete;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return WebPanel(
      title:
          'عمارات عقار ${property.name} · ${property.country.flag} ${property.country.name(english: I18n.isEnglish)}',
      subtitle: 'اختر عمارة لعرض شققها',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('العقارات'),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: onAddBuilding,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('عمارة'),
          ),
        ],
      ),
      child: property.buildings.isEmpty
          ? const WebEmpty(
              title: 'لا توجد عمارات في هذا العقار',
              message: 'أضف عمارة ليتم إنشاء طوابقها وشققها تلقائياً.',
              icon: Icons.apartment_rounded,
            )
          : Column(
              children: [
                for (final building in property.buildings) ...[
                  _BuildingCard(
                    building: building,
                    onTap: () => onOpen(building),
                    onEdit: () => onEdit(building),
                    onDelete: () => onDelete(building),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
    );
  }
}

class _BuildingCard extends StatelessWidget {
  const _BuildingCard({
    required this.building,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Building building;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final units = building.apartments;
    final occupied =
        units.where((a) => a.status == ApartmentStatus.occupied).length;
    final vacant =
        units.where((a) => a.status == ApartmentStatus.vacant).length;
    final rents = units.map((a) => a.rentAmount).where((r) => r > 0).toList();
    final rentRange = rents.isEmpty
        ? '-'
        : rents.length == 1
            ? moneyText(rents.first, country: building.country)
            : '${moneyText(rents.reduce((a, b) => a < b ? a : b), country: building.country)} - ${moneyText(rents.reduce((a, b) => a > b ? a : b), country: building.country)}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .025),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: Colors.white.withValues(alpha: .07)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.apartment_rounded,
                  size: 19, color: AppColors.info),
            ),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${building.totalFloors} طابق · ${units.length} شقة · '
                    '$occupied مؤجرة · $vacant فارغة · $rentRange',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 9.8,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (building.description?.trim().isNotEmpty ?? false)
                    Text(
                      building.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 9.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            WebPill(
              label: '${units.length} شقة',
              color: AppColors.info,
              icon: Icons.door_front_door_rounded,
            ),
            const SizedBox(width: 6),
            WebRowAction(
              icon: Icons.edit_rounded,
              tooltip: tr('تعديل العمارة'),
              onTap: onEdit,
            ),
            WebRowAction(
              icon: Icons.delete_outline_rounded,
              tooltip: tr('حذف العمارة'),
              color: AppColors.danger,
              onTap: onDelete,
            ),
            const Icon(Icons.arrow_back_ios_new_rounded,
                size: 12, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ApartmentsPanel extends StatelessWidget {
  const _ApartmentsPanel({
    required this.property,
    required this.building,
    required this.apartments,
    required this.query,
    required this.onQueryChanged,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onBackToBuildings,
    required this.onBackToProperties,
  });

  final Compound property;
  final Building building;
  final List<Apartment> apartments;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onAdd;
  final ValueChanged<Apartment> onEdit;
  final ValueChanged<Apartment> onDelete;
  final VoidCallback onBackToBuildings;
  final VoidCallback onBackToProperties;

  @override
  Widget build(BuildContext context) {
    return WebPanel(
      title: 'شقق عمارة ${building.name}',
      subtitle:
          '${apartments.length} شقة · ${building.totalFloors} طابق · عقار ${property.name}',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            onPressed: onBackToProperties,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('العقارات'),
          ),
          TextButton.icon(
            onPressed: onBackToBuildings,
            icon: const Icon(Icons.apartment_rounded, size: 16),
            label: const Text('العمارات'),
          ),
          SizedBox(
            width: 180,
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                hintText: tr('بحث برقم الشقة'),
                prefixIcon: Icon(Icons.search_rounded, size: 18),
              ),
              onChanged: onQueryChanged,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _ActionButton(
            label: 'شقة',
            icon: Icons.add_home_rounded,
            onPressed: onAdd,
          ),
        ],
      ),
      child: WebTable(
        minWidth: 1040,
        columns: const [
          WebTableColumn('الوحدة', flex: 2),
          WebTableColumn('الطابق', flex: 1, align: TextAlign.center),
          WebTableColumn('الوصف والتفاصيل', flex: 3),
          WebTableColumn('الغرف', flex: 1, align: TextAlign.center),
          WebTableColumn('المساحة', flex: 1, align: TextAlign.center),
          WebTableColumn('الإيجار', flex: 2),
          WebTableColumn('الحالة', flex: 1, align: TextAlign.center),
          WebTableColumn('إجراءات', flex: 2, align: TextAlign.center),
        ],
        empty: const WebEmpty(
          title: 'لا توجد شقق',
          message: 'أضف شقة لهذه العمارة.',
          icon: Icons.door_front_door_rounded,
        ),
        rows: [
          for (final apartment in apartments)
            [
              Text(
                apartment.displayName,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                apartment.floorLabel.isEmpty
                    ? '—'
                    : apartment.floorLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Tooltip(
                message: apartment.description?.trim().isNotEmpty ?? false
                    ? apartment.description!
                    : 'لا يوجد وصف',
                child: Text(
                  apartment.description?.trim().isNotEmpty ?? false
                      ? apartment.description!
                      : '-',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 10.5,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                '${apartment.roomCount}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                apartment.areaSqm == null
                    ? '-'
                    : '${apartment.areaSqm!.toStringAsFixed(0)} م²',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                moneyText(apartment.rentAmount, country: apartment.country),
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.goldLight,
                ),
              ),
              WebPill(
                label: apartment.status.label,
                color: _PortfolioSectionState.statusColor(apartment.status),
                icon: apartment.status.icon,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  WebRowAction(
                    icon: Icons.edit_rounded,
                    tooltip: tr('تعديل'),
                    onTap: () => onEdit(apartment),
                  ),
                  WebRowAction(
                    icon: Icons.delete_outline_rounded,
                    tooltip: tr('حذف'),
                    color: AppColors.danger,
                    onTap: () => onDelete(apartment),
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
      backgroundColor: filled
          ? const WidgetStatePropertyAll(AppColors.gold)
          : WidgetStatePropertyAll(Colors.white.withValues(alpha: .04)),
      foregroundColor: WidgetStatePropertyAll(
        filled ? AppColors.navy900 : AppColors.textSecondary,
      ),
      side: WidgetStatePropertyAll(
        BorderSide(color: Colors.white.withValues(alpha: filled ? 0 : .12)),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
            fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: style,
    );
  }
}

class _PropertyDialog extends StatefulWidget {
  const _PropertyDialog({
    required this.repository,
    this.property,
    this.initialCountry,
  });

  final SupabaseRepository repository;
  final Compound? property;
  final AppCountry? initialCountry;

  @override
  State<_PropertyDialog> createState() => _PropertyDialogState();
}

class _PropertyDialogState extends State<_PropertyDialog> {
  late final TextEditingController _name;
  late final TextEditingController _location;
  late final TextEditingController _description;
  late AppCountry _country;
  bool _loading = false;
  String? _error;

  bool get _editing => widget.property != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.property?.name ?? '');
    _location = TextEditingController(text: widget.property?.location ?? '');
    _description =
        TextEditingController(text: widget.property?.description ?? '');
    _country = widget.property?.country ?? widget.initialCountry ?? AppCountry.iq;
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'أدخل اسم العقار');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_editing) {
        await widget.repository.updateCompound(
          compoundId: widget.property!.id,
          name: _name.text,
          location: _location.text,
          description: _description.text,
          country: _country,
        );
        if (mounted) Navigator.pop(context, widget.property!.id);
      } else {
        final id = await widget.repository.createCompound(
          name: _name.text,
          location: _location.text,
          description: _description.text,
          country: _country,
        );
        if (mounted) Navigator.pop(context, id);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = friendlyError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? 'تعديل العقار' : 'إضافة عقار'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: tr('اسم العقار'),
                hintText: tr('مثال: عمارة شارع 42'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _location,
              decoration: InputDecoration(
                labelText: tr('الموقع'),
                hintText: tr('مثال: بغداد - الكرادة'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: tr('تفاصيل إضافية (اختياري)'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_editing)
              DropdownButtonFormField<AppCountry>(
                initialValue: _country,
                decoration: InputDecoration(
                  labelText: tr('الدولة والعملة'),
                  prefixIcon: Icon(Icons.public_rounded),
                ),
                items: AppCountry.values
                    .map((country) => DropdownMenuItem(
                          value: country,
                          child: Text(
                            '${country.flag}  ${country.name(english: I18n.isEnglish)} · ${country.currencyCode}',
                          ),
                        ))
                    .toList(),
                onChanged: _loading
                    ? null
                    : (value) {
                        if (value != null) setState(() => _country = value);
                      },
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: .3)),
                ),
                child: Text(
                  '${_country.flag}  ${_country.name(english: I18n.isEnglish)} · ${_country.currencyCode}',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldLight,
                  ),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  color: AppColors.danger,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_editing ? 'حفظ' : 'إضافة'),
        ),
      ],
    );
  }
}

class _BuildingDialog extends StatefulWidget {
  const _BuildingDialog({
    required this.repository,
    required this.properties,
    this.initialPropertyId,
    this.building,
  });

  final SupabaseRepository repository;
  final List<Compound> properties;
  final String? initialPropertyId;
  final Building? building;

  @override
  State<_BuildingDialog> createState() => _BuildingDialogState();
}

class _BuildingDialogState extends State<_BuildingDialog> {
  late String _propertyId;
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _description = TextEditingController();
  final _floors = TextEditingController(text: '3');
  final _units = TextEditingController(text: '2');
  final _rent = TextEditingController();
  final _rooms = TextEditingController(text: '2');
  final _area = TextEditingController();
  bool _loading = false;
  String? _error;

  bool get _editing => widget.building != null;

  @override
  void initState() {
    super.initState();
    _propertyId = widget.initialPropertyId ??
        widget.building?.compoundId ??
        widget.properties.first.id;
    final building = widget.building;
    if (building != null) {
      _name.text = building.name;
      _address.text = building.address ?? '';
      _description.text = building.description ?? '';
      _floors.text = '${building.totalFloors}';
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _address,
      _description,
      _floors,
      _units,
      _rent,
      _rooms,
      _area,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final floors = int.tryParse(_floors.text.trim());

    if (_name.text.trim().length < 2) {
      setState(() => _error = 'أدخل اسم العمارة');
      return;
    }
    if (floors == null || floors < 1 || floors > 60) {
      setState(() => _error = 'عدد الطوابق يجب أن يكون بين 1 و60');
      return;
    }

    if (_editing) {
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        await widget.repository.updateBuilding(
          buildingId: widget.building!.id,
          name: _name.text,
          address: _address.text,
          description: _description.text,
          totalFloors: floors,
        );
        if (mounted) Navigator.pop(context, true);
      } catch (error) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = friendlyError(error);
          });
        }
      }
      return;
    }

    final units = int.tryParse(_units.text.trim());
    final rent = double.tryParse(_rent.text.trim());
    final rooms = int.tryParse(_rooms.text.trim());
    final area = double.tryParse(_area.text.trim());

    if (units == null || units < 0 || units > 50) {
      setState(() => _error = 'عدد الشقق في الطابق يجب أن يكون بين 0 و50');
      return;
    }
    if (rent == null || rent < 0) {
      setState(() => _error = 'أدخل قيمة إيجار صحيحة');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.createBuilding(
        compoundId: _propertyId,
        name: _name.text,
        address: _address.text,
        floors: floors,
        unitsPerFloor: units,
        rent: rent,
        rooms: rooms ?? 2,
        area: area,
      );
      if (mounted) Navigator.pop(context, _propertyId);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = friendlyError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? 'تعديل العمارة' : 'إضافة عمارة'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_editing) ...[
                DropdownButtonFormField<String>(
                  value: _propertyId,
                  decoration: InputDecoration(labelText: tr('العقار')),
                  items: [
                    for (final property in widget.properties)
                      DropdownMenuItem(
                        value: property.id,
                        child: Text(property.name),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _propertyId = value);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: tr('اسم العمارة'),
                  hintText: tr('مثال: عمارة أ'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _address,
                decoration: InputDecoration(
                  labelText: tr('العنوان / الموقع'),
                  hintText: tr('مثال: شارع 14 - قرب الجامعة'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _description,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: tr('وصف العمارة وتفاصيلها'),
                  hintText: tr('مثال: عمارة سكنية 4 طوابق، مدخلان، مصعد، موقف سيارات…'),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _floors,
                      keyboardType: TextInputType.number,
                      decoration:
                          InputDecoration(labelText: tr('عدد الطوابق')),
                    ),
                  ),
                  if (!_editing) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _units,
                        keyboardType: TextInputType.number,
                        decoration:
                            InputDecoration(labelText: tr('شقق كل طابق')),
                      ),
                    ),
                  ],
                ],
              ),
              if (!_editing) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _rent,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: tr('إيجار الشقة'),
                          hintText: '500000',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _rooms,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: tr('الغرف')),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _area,
                        keyboardType: TextInputType.number,
                        decoration:
                            InputDecoration(labelText: tr('المساحة م²')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'سيتم إنشاء الطوابق وتوزيع الشقق تلقائياً بأرقام مثل 101 و102، ويمكن تعديل اسم ورقم وطابق ووصف كل شقة لاحقاً.',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 10,
                    height: 1.6,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_editing ? 'حفظ التعديلات' : 'إضافة العمارة'),
        ),
      ],
    );
  }
}

class _ApartmentDialog extends StatefulWidget {
  const _ApartmentDialog({
    required this.repository,
    this.building,
    this.apartment,
  });

  final SupabaseRepository repository;
  final Building? building;
  final Apartment? apartment;

  @override
  State<_ApartmentDialog> createState() => _ApartmentDialogState();
}

class _ApartmentDialogState extends State<_ApartmentDialog> {
  final _unit = TextEditingController();
  final _floor = TextEditingController(text: '1');
  final _floorName = TextEditingController();
  final _rent = TextEditingController();
  final _rooms = TextEditingController(text: '2');
  final _area = TextEditingController();
  final _description = TextEditingController();
  ApartmentStatus _status = ApartmentStatus.vacant;
  bool _loading = false;
  String? _error;

  bool get _editing => widget.apartment != null;

  @override
  void initState() {
    super.initState();
    final apartment = widget.apartment;
    if (apartment != null) {
      _unit.text = apartment.unitNumber;
      _floor.text = '${apartment.floorNumber ?? 1}';
      _floorName.text = apartment.floorLabelText ?? '';
      _rent.text = apartment.rentAmount.toStringAsFixed(0);
      _rooms.text = '${apartment.roomCount}';
      _area.text = apartment.areaSqm?.toStringAsFixed(0) ?? '';
      _description.text = apartment.description ?? '';
      _status = apartment.status;
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _unit,
      _floor,
      _floorName,
      _rent,
      _rooms,
      _area,
      _description
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final rent = double.tryParse(_rent.text.trim());
    final rooms = int.tryParse(_rooms.text.trim()) ?? 2;
    final area = double.tryParse(_area.text.trim());
    final floor = int.tryParse(_floor.text.trim());

    if (_unit.text.trim().isEmpty) {
      setState(() => _error = 'أدخل اسم الشقة (كتابة أو رقم)');
      return;
    }
    if (floor == null || floor < 0 || floor > 200) {
      setState(() => _error = 'رقم الطابق يجب أن يكون بين 0 و200 (0 = أرضي)');
      return;
    }
    if (rent == null || rent < 0) {
      setState(() => _error = 'أدخل قيمة إيجار صحيحة');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_editing) {
        await widget.repository.updateApartment(
          apartmentId: widget.apartment!.id,
          rent: rent,
          status: _status.dbValue,
          rooms: rooms,
          area: area,
          description: _description.text,
          unitNumber: _unit.text,
          floorNumber: floor,
          floorLabel: _floorName.text,
        );
      } else {
        await widget.repository.createApartment(
          buildingId: widget.building!.id,
          floorNumber: floor,
          unitNumber: _unit.text,
          rent: rent,
          rooms: rooms,
          area: area,
          description: _description.text,
          floorLabel: _floorName.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = friendlyError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? 'تعديل الشقة' : 'إضافة شقة'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _unit,
                      decoration: InputDecoration(
                        labelText: tr('اسم الشقة أو رقمها'),
                        hintText: tr('مثال: شقة رقم واحد أو 101'),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _floor,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: tr('رقم الطابق'),
                        helperText: tr('0 = أرضي'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _floorName,
                decoration: InputDecoration(
                  labelText: tr('اسم الطابق بالكتابة (اختياري)'),
                  hintText: tr('مثال: الطابق الأول - فوق المحلات'),
                  helperText: tr('يظهر مكان رقم الطابق، ويبقى الرقم للترتيب فقط'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _rent,
                      keyboardType: TextInputType.number,
                      decoration:
                          InputDecoration(labelText: tr('الإيجار الشهري')),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _rooms,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: tr('الغرف')),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _area,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: tr('م²')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<ApartmentStatus>(
                value: _status,
                decoration: InputDecoration(labelText: tr('الحالة')),
                items: [
                  for (final status in ApartmentStatus.values)
                    DropdownMenuItem(value: status, child: Text(status.label)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _status = value);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _description,
                minLines: 5,
                maxLines: 12,
                decoration: InputDecoration(
                  labelText: tr('وصف الشقة والتفاصيل الكاملة'),
                  hintText: tr(
                      'اكتب كل التفاصيل: التصميم، عدد الغرف والصالات، الأرضية، '
                      'المطبخ، الحمامات، البلكونة، الإطلالة، التدفئة، التكييف…'),
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_editing ? 'حفظ' : 'إضافة'),
        ),
      ],
    );
  }
}
