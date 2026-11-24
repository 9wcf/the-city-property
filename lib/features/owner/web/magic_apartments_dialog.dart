import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_utils.dart';
import '../../../core/widgets/premium_widgets.dart';
import '../../../data/models.dart';
import '../../shared/lease_documents_sheet.dart';
import 'web_ui.dart';
import '../../../core/i18n/app_country.dart';
import '../../../core/i18n/i18n.dart';

enum _UnitFilter { all, rented, vacant, maintenance, reserved }

extension on _UnitFilter {
  String get label => switch (this) {
        _UnitFilter.all => 'الكل',
        _UnitFilter.rented => 'مؤجرة',
        _UnitFilter.vacant => 'فارغة',
        _UnitFilter.maintenance => 'صيانة',
        _UnitFilter.reserved => 'محجوزة',
      };

  bool matches(ApartmentStatus status) => switch (this) {
        _UnitFilter.all => true,
        _UnitFilter.rented => status == ApartmentStatus.occupied,
        _UnitFilter.vacant => status == ApartmentStatus.vacant,
        _UnitFilter.maintenance => status == ApartmentStatus.maintenance,
        _UnitFilter.reserved => status == ApartmentStatus.reserved,
      };
}

class MagicApartmentsDialog extends ConsumerStatefulWidget {
  const MagicApartmentsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .78),
      builder: (_) => const MagicApartmentsDialog(),
    );
  }

  @override
  ConsumerState<MagicApartmentsDialog> createState() =>
      _MagicApartmentsDialogState();
}

class _MagicApartmentsDialogState extends ConsumerState<MagicApartmentsDialog> {
  final TextEditingController _search = TextEditingController();
  _UnitFilter _filter = _UnitFilter.all;
  String? _buildingId;
  bool _refreshing = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    ref.invalidate(ownerDashboardProvider);
    try {
      await ref.read(ownerDashboardProvider.future);
    } catch (_) {
      // The provider watch below renders the error state.
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  List<_UnitInfo> _collect(OwnerDashboardData data, AppCountry country) {
    final tenants = <String, TenantRecord>{
      for (final tenant in data.snapshot.tenants) tenant.apartment.id: tenant,
    };
    final invoices = <String, List<Invoice>>{};
    for (final invoice in data.invoices) {
      invoices.putIfAbsent(invoice.apartmentId, () => []).add(invoice);
    }
    final units = <_UnitInfo>[];
    for (final property in data.snapshot.portfolio.compounds) {
      if (property.country != country) continue;
      for (final building in property.buildings) {
        for (final apartment in building.apartments) {
          final tenant = tenants[apartment.id];
          units.add(_UnitInfo(
            property: property,
            building: building,
            apartment: apartment,
            tenant: tenant,
            lease: tenant?.lease,
            invoices: invoices[apartment.id] ?? const [],
          ));
        }
      }
    }
    return units;
  }

  List<_UnitInfo> _visible(List<_UnitInfo> units) {
    final query = _search.text.trim().toLowerCase();
    return units.where((unit) {
      if (!_filter.matches(unit.apartment.status)) return false;
      if (_buildingId != null && unit.building.id != _buildingId) return false;
      if (query.isEmpty) return true;
      final searchable = [
        unit.apartment.unitNumber,
        unit.apartment.description ?? '',
        unit.apartment.floorLabel,
        unit.building.name,
        unit.property.name,
        unit.tenantName,
        unit.tenantPhone,
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(ownerDashboardProvider);
    final country = ref.watch(ownerCountryProvider);
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1220,
          maxHeight: size.height - 32,
        ),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.navy850, AppColors.navy900],
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.gold.withValues(alpha: .35)),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: .12),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: dashboard.when(
            loading: () => const SizedBox(
              height: 320,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
            ),
            error: (error, _) => SizedBox(
              height: 320,
              child: ErrorView(
                message: friendlyError(error),
                onRetry: () => ref.invalidate(ownerDashboardProvider),
              ),
            ),
            data: (data) {
              final units = _collect(data, country);
              final visible = _visible(units);
              final monthlyExpected = units
                  .where((unit) =>
                      unit.apartment.status == ApartmentStatus.occupied)
                  .fold<double>(
                      0, (sum, unit) => sum + unit.apartment.rentAmount);
              final collectedThisMonth = units.fold<double>(
                  0, (sum, unit) => sum + (unit.tenant?.paidThisMonth ?? 0));
              final outstanding = units.fold<double>(
                  0, (sum, unit) => sum + unit.outstanding);
              final buildings = <String, _BuildingOption>{};
              for (final unit in units) {
                buildings[unit.building.id] = _BuildingOption(
                  id: unit.building.id,
                  label: '${unit.building.name} · ${unit.property.name}',
                );
              }
              final buildingOptions = buildings.values.toList()
                ..sort((a, b) => a.label.compareTo(b.label));
              return Column(
                children: [
                  _Header(
                    title: I18n.isEnglish
                        ? 'Magic button — ${country.name(english: true)} apartments'
                        : 'الزر السحري — شقق ${country.name(english: false)}',
                    refreshing: _refreshing,
                    onRefresh: _refresh,
                    onClose: () => Navigator.of(context).maybePop(),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Summary(
                            units: units,
                            monthlyExpected: monthlyExpected,
                            collectedThisMonth: collectedThisMonth,
                            outstanding: outstanding,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _Toolbar(
                            search: _search,
                            filter: _filter,
                            buildings: buildingOptions,
                            buildingId: _buildingId,
                            units: units,
                            onFilter: (value) => setState(() => _filter = value),
                            onBuilding: (value) =>
                                setState(() => _buildingId = value),
                            onSearch: (_) => setState(() {}),
                            onClearSearch: () {
                              _search.clear();
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (visible.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: AppSpacing.xxl),
                              child: _EmptyResult(),
                            )
                          else
                            _GroupedUnits(
                              units: visible,
                              onDetails: (unit) =>
                                  _UnitDetailsDialog.show(context, unit),
                              onDocuments: (unit) => LeaseDocumentsSheet.show(
                                context,
                                lease: unit.lease!,
                                tenantName: unit.tenantName,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BuildingOption {
  const _BuildingOption({required this.id, required this.label});

  final String id;
  final String label;
}

class _UnitInfo {
  const _UnitInfo({
    required this.property,
    required this.building,
    required this.apartment,
    required this.tenant,
    required this.lease,
    required this.invoices,
  });

  final Compound property;
  final Building building;
  final Apartment apartment;
  final TenantRecord? tenant;
  final Lease? lease;
  final List<Invoice> invoices;

  String get tenantName =>
      tenant?.profile.displayName ?? lease?.tenantName ?? 'غير مرتبط بمستأجر';

  String get tenantPhone =>
      tenant?.profile.phoneNumber ?? lease?.tenantPhone ?? '';

  String get tenantEmail => tenant?.profile.email ?? '';

  double get monthlyRent => lease?.monthlyRent ?? apartment.rentAmount;

  double get paidThisMonth => tenant?.paidThisMonth ?? 0;

  double get remainingThisMonth =>
      (monthlyRent - paidThisMonth).clamp(0, double.infinity).toDouble();

  int get daysLeft => lease == null ? 0 : daysUntil(lease!.endDate);

  int get monthsLeft {
    if (lease == null) return 0;
    final now = DateTime.now();
    final end = lease!.endDate;
    if (!end.isAfter(now)) return 0;
    var months = (end.year - now.year) * 12 + (end.month - now.month);
    if (end.day < now.day) months -= 1;
    return months < 1 ? 1 : months;
  }

  double get remainingContract =>
      lease == null ? 0 : monthlyRent * monthsLeft;

  double get outstanding =>
      invoices.fold<double>(0, (sum, invoice) => sum + invoice.remaining);

  int get overdueCount =>
      invoices.where((invoice) => invoice.isOverdue).length;

  bool get hasLease => lease != null;

  bool get hasTenant => tenant != null || lease != null;

  bool get leaseExpiringSoon =>
      lease != null && daysLeft >= 0 && daysLeft <= 60;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.refreshing,
    required this.onRefresh,
    required this.onClose,
  });

  final String title;
  final bool refreshing;
  final VoidCallback onRefresh;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.md, AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .02),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: .07)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: .35),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 24, color: AppColors.navy900),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'المؤجرة والفارغة · العمارة والمستأجر · المتبقي من الإيجار وكل التفاصيل',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: tr('تحديث البيانات'),
            onPressed: refreshing ? null : onRefresh,
            icon: refreshing
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.gold),
                  )
                : const Icon(Icons.refresh_rounded,
                    size: 21, color: AppColors.textSecondary),
          ),
          IconButton(
            tooltip: tr('إغلاق'),
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded,
                size: 22, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.units,
    required this.monthlyExpected,
    required this.collectedThisMonth,
    required this.outstanding,
  });

  final List<_UnitInfo> units;
  final double monthlyExpected;
  final double collectedThisMonth;
  final double outstanding;

  @override
  Widget build(BuildContext context) {
    final rented = units
        .where((u) => u.apartment.status == ApartmentStatus.occupied)
        .toList();
    final vacant = units
        .where((u) => u.apartment.status == ApartmentStatus.vacant)
        .length;
    final other = units.length - rented.length - vacant;
    final remainingThisMonth = rented.fold<double>(
        0, (sum, unit) => sum + unit.remainingThisMonth);
    final expiring = units.where((unit) => unit.leaseExpiringSoon).length;
    final overdueUnits =
        units.where((unit) => unit.overdueCount > 0).length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatTile(
          label: 'إجمالي الشقق',
          value: '${units.length}',
          icon: Icons.door_front_door_rounded,
          color: AppColors.textPrimary,
        ),
        _StatTile(
          label: 'شقق مؤجرة',
          value: '${rented.length}',
          icon: Icons.check_circle_rounded,
          color: AppColors.occupied,
        ),
        _StatTile(
          label: 'شقق فارغة',
          value: '$vacant',
          icon: Icons.home_outlined,
          color: AppColors.pending,
        ),
        _StatTile(
          label: 'صيانة / محجوزة',
          value: '$other',
          icon: Icons.build_rounded,
          color: AppColors.info,
        ),
        _StatTile(
          label: 'الإيجار الشهري المتوقع',
          value: moneyText(monthlyExpected),
          icon: Icons.payments_rounded,
          color: AppColors.gold,
        ),
        _StatTile(
          label: 'محصّل هذا الشهر',
          value: moneyText(collectedThisMonth),
          icon: Icons.savings_rounded,
          color: AppColors.occupied,
        ),
        _StatTile(
          label: 'متبقي إيجار هذا الشهر',
          value: moneyText(remainingThisMonth),
          icon: Icons.hourglass_bottom_rounded,
          color: remainingThisMonth > 0 ? AppColors.pending : AppColors.occupied,
        ),
        _StatTile(
          label: 'متأخرات الفواتير',
          value: moneyText(outstanding),
          icon: Icons.receipt_long_rounded,
          color: outstanding > 0
              ? AppColors.danger
              : AppColors.occupied,
          caption: overdueUnits > 0 ? '$overdueUnits شقة عليها متأخرات' : null,
        ),
        _StatTile(
          label: 'عقود تنتهي خلال 60 يوم',
          value: '$expiring',
          icon: Icons.event_busy_rounded,
          color: expiring > 0 ? AppColors.pending : AppColors.occupied,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.caption,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 184,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .20)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13.5,
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
                    fontSize: 9.5,
                    color: AppColors.textMuted,
                  ),
                ),
                if (caption != null)
                  Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 8.5,
                      color: color.withValues(alpha: .85),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.search,
    required this.filter,
    required this.buildings,
    required this.buildingId,
    required this.units,
    required this.onFilter,
    required this.onBuilding,
    required this.onSearch,
    required this.onClearSearch,
  });

  final TextEditingController search;
  final _UnitFilter filter;
  final List<_BuildingOption> buildings;
  final String? buildingId;
  final List<_UnitInfo> units;
  final ValueChanged<_UnitFilter> onFilter;
  final ValueChanged<String?> onBuilding;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;

  int _count(_UnitFilter option) =>
      units.where((unit) => option.matches(unit.apartment.status)).length;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 250,
          child: TextField(
            controller: search,
            onChanged: onSearch,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: tr('ابحث بشقة، عمارة، مستأجر أو رقم هاتف'),
              hintStyle: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11,
                color: AppColors.textMuted,
              ),
              prefixIcon:
                  const Icon(Icons.search_rounded, size: 18),
              suffixIcon: search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: tr('مسح البحث'),
                      onPressed: onClearSearch,
                      icon: const Icon(Icons.close_rounded, size: 16),
                    ),
            ),
          ),
        ),
        for (final option in _UnitFilter.values)
          ChoiceChip(
            label: Text('${option.label} (${_count(option)})'),
            selected: filter == option,
            showCheckmark: false,
            onSelected: (_) => onFilter(option),
            labelStyle: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: filter == option
                  ? AppColors.navy900
                  : AppColors.textSecondary,
            ),
            selectedColor: AppColors.gold,
            backgroundColor: Colors.white.withValues(alpha: .035),
            side: BorderSide(
              color: filter == option
                  ? AppColors.gold
                  : Colors.white.withValues(alpha: .10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          ),
        if (buildings.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .035),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: Colors.white.withValues(alpha: .10)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: buildingId,
                hint: const Text(
                  'كل العمارات',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                dropdownColor: AppColors.navy800,
                borderRadius: BorderRadius.circular(12),
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: AppColors.textMuted),
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  color: AppColors.textPrimary,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      'كل العمارات',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  for (final option in buildings)
                    DropdownMenuItem<String?>(
                      value: option.id,
                      child: Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                ],
                onChanged: onBuilding,
              ),
            ),
          ),
      ],
    );
  }
}

class _GroupedUnits extends StatelessWidget {
  const _GroupedUnits({
    required this.units,
    required this.onDetails,
    required this.onDocuments,
  });

  final List<_UnitInfo> units;
  final ValueChanged<_UnitInfo> onDetails;
  final ValueChanged<_UnitInfo> onDocuments;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<_UnitInfo>>{};
    for (final unit in units) {
      groups.putIfAbsent(unit.building.id, () => []).add(unit);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final columns = constraints.maxWidth >= 1050
            ? 3
            : constraints.maxWidth >= 700
                ? 2
                : 1;
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in groups.entries) ...[
              _GroupHeader(units: entry.value),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final unit in entry.value)
                    SizedBox(
                      width: cardWidth,
                      child: _UnitCard(
                        unit: unit,
                        onDetails: () => onDetails(unit),
                        onDocuments:
                            unit.hasLease ? () => onDocuments(unit) : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        );
      },
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.units});

  final List<_UnitInfo> units;

  @override
  Widget build(BuildContext context) {
    final first = units.first;
    final rented = units
        .where((u) => u.apartment.status == ApartmentStatus.occupied)
        .length;
    final vacant = units
        .where((u) => u.apartment.status == ApartmentStatus.vacant)
        .length;
    return Row(
      children: [
        const Icon(Icons.apartment_rounded, size: 17, color: AppColors.info),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${first.building.name} · ${first.property.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          '${units.length} شقة · $rented مؤجرة · $vacant فارغة',
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 10,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.unit,
    required this.onDetails,
    this.onDocuments,
  });

  final _UnitInfo unit;
  final VoidCallback onDetails;
  final VoidCallback? onDocuments;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(unit.apartment.status);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.navy800.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(unit.apartment.status.icon, size: 18, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.apartment.displayName,
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
                      [
                        if (unit.apartment.floorLabel.isNotEmpty)
                          unit.apartment.floorLabel,
                        if (unit.apartment.roomCount > 0)
                          '${unit.apartment.roomCount} غرف',
                        if (unit.apartment.areaSqm != null)
                          '${unit.apartment.areaSqm!.toStringAsFixed(0)} م²',
                      ].join(' · '),
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
              _MiniPill(
                label: unit.apartment.status.label,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 9),
          const Divider(height: 1),
          const SizedBox(height: 9),
          if (unit.hasTenant) ...[
            _InfoLine(
              icon: Icons.person_rounded,
              label: 'المستأجر',
              value: unit.tenantName,
              color: AppColors.goldLight,
              trailing: unit.tenantPhone.isEmpty
                  ? null
                  : Text(
                      prettyPhone(unit.tenantPhone),
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
            ),
            const SizedBox(height: 5),
            _InfoLine(
              icon: Icons.event_rounded,
              label: 'العقد',
              value: unit.lease == null
                  ? 'لا يوجد عقد نشط'
                  : '${formatDate(unit.lease!.startDate)} ← ${formatDate(unit.lease!.endDate)}',
              color: unit.lease == null
                  ? AppColors.textMuted
                  : unit.daysLeft < 0
                      ? AppColors.danger
                      : unit.leaseExpiringSoon
                          ? AppColors.pending
                          : AppColors.textSecondary,
              trailing: unit.lease == null
                  ? null
                  : Text(
                      unit.daysLeft < 0
                          ? 'منتهي منذ ${-unit.daysLeft} يوم'
                          : 'باقي ${unit.daysLeft} يوم',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: unit.daysLeft < 0
                            ? AppColors.danger
                            : unit.leaseExpiringSoon
                                ? AppColors.pending
                                : AppColors.occupied,
                      ),
                    ),
            ),
            const SizedBox(height: 5),
            _InfoLine(
              icon: Icons.payments_rounded,
              label: 'الإيجار الشهري',
              value: moneyText(unit.monthlyRent),
              color: AppColors.goldLight,
            ),
            const SizedBox(height: 5),
            _InfoLine(
              icon: Icons.savings_rounded,
              label: 'مدفوع هذا الشهر',
              value: moneyText(unit.paidThisMonth),
              color: AppColors.occupied,
            ),
            const SizedBox(height: 5),
            _InfoLine(
              icon: Icons.hourglass_bottom_rounded,
              label: 'متبقي هذا الشهر',
              value: moneyText(unit.remainingThisMonth),
              color: unit.remainingThisMonth > 0
                  ? AppColors.pending
                  : AppColors.occupied,
            ),
            const SizedBox(height: 5),
            _InfoLine(
              icon: Icons.calculate_rounded,
              label: 'متبقي من قيمة العقد',
              value: unit.lease == null
                  ? '—'
                  : moneyText(unit.remainingContract),
              color: AppColors.info,
              trailing: unit.lease == null
                  ? null
                  : Text(
                      '${unit.monthsLeft} شهر',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 9.5,
                        color: AppColors.textMuted,
                      ),
                    ),
            ),
            if (unit.outstanding > 0 || unit.overdueCount > 0) ...[
              const SizedBox(height: 5),
              _InfoLine(
                icon: Icons.receipt_long_rounded,
                label: 'متأخرات الفواتير',
                value: moneyText(unit.outstanding),
                color: AppColors.danger,
                trailing: unit.overdueCount == 0
                    ? null
                    : Text(
                        '${unit.overdueCount} فاتورة متأخرة',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 9.5,
                          color: AppColors.danger,
                        ),
                      ),
              ),
            ],
          ] else ...[
            _InfoLine(
              icon: Icons.payments_rounded,
              label: 'الإيجار المطلوب',
              value: moneyText(unit.apartment.rentAmount),
              color: AppColors.goldLight,
            ),
            const SizedBox(height: 5),
            const _InfoLine(
              icon: Icons.home_outlined,
              label: 'الحالة',
              value: 'متاحة للإيجار',
              color: AppColors.pending,
            ),
          ],
          if (unit.apartment.description?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 5),
            _InfoLine(
              icon: Icons.notes_rounded,
              label: 'تفاصيل الشقة',
              value: unit.apartment.description!,
              color: AppColors.textSecondary,
              maxLines: 2,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDetails,
                  icon: const Icon(Icons.visibility_rounded, size: 15),
                  label: const Text('كل التفاصيل'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: BorderSide(
                        color: AppColors.gold.withValues(alpha: .38)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    textStyle: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (onDocuments != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: tr('المستمسكات وصور العقد'),
                  onPressed: onDocuments,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.folder_copy_rounded,
                      size: 18, color: AppColors.gold),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.trailing,
    this.maxLines = 1,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Widget? trailing;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 13, color: color.withValues(alpha: .8)),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 8.5,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                value,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: trailing!,
          ),
        ],
      ],
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 40, color: AppColors.textMuted),
          SizedBox(height: AppSpacing.sm),
          Text(
            'لا توجد شقق مطابقة',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'جرّب تغيير الفلتر أو البحث.',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 10,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(ApartmentStatus status) => switch (status) {
      ApartmentStatus.occupied => AppColors.occupied,
      ApartmentStatus.vacant => AppColors.pending,
      ApartmentStatus.maintenance => AppColors.info,
      ApartmentStatus.reserved => AppColors.reserved,
    };

String _leaseStatusLabel(String status) => switch (status) {
      'active' => 'نشط',
      'pending' => 'بانتظار الموافقة',
      'expired' => 'منتهي',
      'terminated' => 'ملغى',
      'rejected' => 'مرفوض',
      _ => status,
    };

class _UnitDetailsDialog extends StatelessWidget {
  const _UnitDetailsDialog({required this.unit});

  final _UnitInfo unit;

  static Future<void> show(BuildContext context, _UnitInfo unit) {
    return showDialog<void>(
      context: context,
      builder: (_) => _UnitDetailsDialog(unit: unit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(unit.apartment.status);
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: size.height - 32,
        ),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.navy850, AppColors.navy900],
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: color.withValues(alpha: .35)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .05),
                  border: Border(
                    bottom: BorderSide(
                        color: Colors.white.withValues(alpha: .07)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child:
                          Icon(unit.apartment.status.icon, color: color, size: 21),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${unit.apartment.displayName} · ${unit.building.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${unit.property.name}'
                            '${unit.apartment.floorLabel.isEmpty ? '' : ' · ${unit.apartment.floorLabel}'}',
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
                    _MiniPill(
                        label: unit.apartment.status.label, color: color),
                    IconButton(
                      tooltip: tr('إغلاق'),
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded,
                          size: 20, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DetailsSection(
                        title: 'بيانات الشقة',
                        icon: Icons.door_front_door_rounded,
                        children: [
                          _DetailsGrid(
                            entries: [
                              ('العقار', unit.property.name),
                              ('العمارة', unit.building.name),
                              (
                                'الطابق',
                                unit.apartment.floorLabel.isEmpty
                                    ? '—'
                                    : unit.apartment.floorLabel
                              ),
                              ('اسم الشقة', unit.apartment.displayName),
                              ('الحالة', unit.apartment.status.label),
                              ('الإيجار الشهري',
                                  moneyText(unit.apartment.rentAmount)),
                              ('عدد الغرف', '${unit.apartment.roomCount}'),
                              (
                                'المساحة',
                                unit.apartment.areaSqm == null
                                    ? '—'
                                    : '${unit.apartment.areaSqm!.toStringAsFixed(0)} م²'
                              ),
                            ],
                          ),
                          if (unit.building.description
                                  ?.trim()
                                  .isNotEmpty ??
                              false) ...[
                            const SizedBox(height: AppSpacing.sm),
                            _DetailsText(
                              label: 'عن العمارة',
                              value: unit.building.description!,
                            ),
                          ],
                          if (unit.apartment.description?.trim().isNotEmpty ??
                              false) ...[
                            const SizedBox(height: AppSpacing.sm),
                            _DetailsText(
                              label: 'وصف الشقة وتفاصيلها',
                              value: unit.apartment.description!,
                            ),
                          ],
                        ],
                      ),
                      if (unit.hasTenant) ...[
                        const SizedBox(height: AppSpacing.md),
                        _DetailsSection(
                          title: 'المستأجر',
                          icon: Icons.person_rounded,
                          children: [
                            _DetailsGrid(
                              entries: [
                                ('الاسم', unit.tenantName),
                                (
                                  'الهاتف',
                                  unit.tenantPhone.isEmpty
                                      ? '—'
                                      : prettyPhone(unit.tenantPhone)
                                ),
                                (
                                  'البريد الإلكتروني',
                                  unit.tenantEmail.isEmpty
                                      ? '—'
                                      : unit.tenantEmail
                                ),
                                (
                                  'حالة الحساب',
                                  unit.tenant?.profile.isActive == false
                                      ? 'موقوف'
                                      : 'نشط'
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                      if (unit.lease != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        _DetailsSection(
                          title: 'عقد الإيجار',
                          icon: Icons.description_rounded,
                          children: [
                            _DetailsGrid(
                              entries: [
                                (
                                  'بداية العقد',
                                  formatDate(unit.lease!.startDate)
                                ),
                                ('نهاية العقد', formatDate(unit.lease!.endDate)),
                                (
                                  'المتبقي',
                                  unit.daysLeft < 0
                                      ? 'انتهى منذ ${-unit.daysLeft} يوم'
                                      : '${unit.daysLeft} يوم · ${unit.monthsLeft} شهر'
                                ),
                                (
                                  'حالة العقد',
                                  _leaseStatusLabel(unit.lease!.status)
                                ),
                                (
                                  'الإيجار الشهري',
                                  moneyText(unit.lease!.monthlyRent)
                                ),
                                (
                                  'التأمين',
                                  moneyText(unit.lease!.depositAmount)
                                ),
                                (
                                  'قيمة متبقية من العقد',
                                  moneyText(unit.remainingContract)
                                ),
                                (
                                  'مدفوع هذا الشهر',
                                  moneyText(unit.paidThisMonth)
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _DetailsText(
                              label: 'متبقي إيجار هذا الشهر',
                              value: moneyText(unit.remainingThisMonth),
                            ),
                            if (unit.lease!.notes?.trim().isNotEmpty ??
                                false) ...[
                              const SizedBox(height: AppSpacing.sm),
                              _DetailsText(
                                label: 'ملاحظات العقد',
                                value: unit.lease!.notes!,
                              ),
                            ],
                            if (unit.lease!.terms?.trim().isNotEmpty ??
                                false) ...[
                              const SizedBox(height: AppSpacing.sm),
                              _DetailsText(
                                label: 'شروط العقد',
                                value: unit.lease!.terms!,
                              ),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      _DetailsSection(
                        title: 'الوضع المالي',
                        icon: Icons.receipt_long_rounded,
                        children: [
                          _DetailsGrid(
                            entries: [
                              (
                                'متبقي هذا الشهر',
                                moneyText(unit.remainingThisMonth)
                              ),
                              (
                                'إجمالي متأخرات الفواتير',
                                moneyText(unit.outstanding)
                              ),
                              ('عدد الفواتير', '${unit.invoices.length}'),
                              ('فواتير متأخرة', '${unit.overdueCount}'),
                            ],
                          ),
                          if (unit.invoices.isEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            const Text(
                              'لا توجد فواتير مسجلة لهذه الشقة.',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: AppSpacing.sm),
                            for (final invoice in unit.invoices.take(8))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: _InvoiceRow(invoice: invoice),
                              ),
                            if (unit.invoices.length > 8)
                              Text(
                                'و${unit.invoices.length - 8} فاتورة أخرى…',
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 9,
                                  color: AppColors.textMuted,
                                ),
                              ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (unit.hasLease)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                          color: Colors.white.withValues(alpha: .07)),
                    ),
                  ),
                  child: FilledButton.icon(
                    onPressed: () => LeaseDocumentsSheet.show(
                      context,
                      lease: unit.lease!,
                      tenantName: unit.tenantName,
                    ),
                    icon: const Icon(Icons.folder_copy_rounded, size: 18),
                    label: const Text('المستمسكات وصور العقد'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.navy900,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .025),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.gold),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}

class _DetailsGrid extends StatelessWidget {
  const _DetailsGrid({required this.entries});

  final List<(String, String)> entries;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final columns = constraints.maxWidth >= 520 ? 2 : 1;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final entry in entries)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .03),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 9.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          entry.$2,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DetailsText extends StatelessWidget {
  const _DetailsText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .03),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 9.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final color = invoice.isPaid
        ? AppColors.occupied
        : invoice.isOverdue
            ? AppColors.danger
            : AppColors.pending;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .03),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: .16)),
      ),
      child: Row(
        children: [
          Icon(Icons.receipt_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${invoice.number} · ${formatDate(invoice.invoiceDate)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            '${moneyText(invoice.paidAmount)} / ${moneyText(invoice.totalAmount)}',
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 9.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          _MiniPill(label: invoice.statusLabel, color: color),
        ],
      ),
    );
  }
}
