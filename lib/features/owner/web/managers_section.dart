import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_utils.dart';
import '../../../core/widgets/premium_widgets.dart';
import '../../../data/models.dart';
import '../../../data/repositories.dart';
import 'web_ui.dart';

class ManagersSection extends ConsumerWidget {
  const ManagersSection({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(ownerSnapshotProvider);
    ref.invalidate(ownerDashboardProvider);
    ref.invalidate(compoundManagersProvider);
    ref.invalidate(apartmentManagersProvider);
    await ref.read(ownerDashboardProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(ownerDashboardProvider);
    final compoundsAsync = ref.watch(compoundManagersProvider);
    final apartmentsAsync = ref.watch(apartmentManagersProvider);
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
        final portfolio = Portfolio(
          data.snapshot.portfolio.compounds
              .where((compound) => compound.country == country)
              .toList(),
        );
        final compoundNames = {
          for (final compound in portfolio.compounds) compound.id: compound.name,
        };
        final countryCompoundIds =
            portfolio.compounds.map((compound) => compound.id).toSet();
        final countryApartmentIds =
            portfolio.apartments.map((apartment) => apartment.id).toSet();
        final compoundAssignments = compoundsAsync.maybeWhen(
          data: (value) => value
              .where((assignment) =>
                  countryCompoundIds.contains(assignment.compoundId))
              .toList(),
          orElse: () => const <CompoundManagerAssignment>[],
        );
        final apartmentAssignments = apartmentsAsync.maybeWhen(
          data: (value) => value
              .where((assignment) =>
                  countryApartmentIds.contains(assignment.apartmentId))
              .toList(),
          orElse: () => const <ApartmentManagerAssignment>[],
        );
        final managerIds = <String>{
          ...compoundAssignments.map((assignment) => assignment.managerId),
          ...apartmentAssignments.map((assignment) => assignment.managerId),
        };
        final managers = data.managers
            .where((manager) => managerIds.contains(manager.id))
            .toList();
        final totalUnits = countryApartmentIds.length;

        // A compound manager covers every unit of that compound unless the
        // unit has its own direct assignment (direct wins).
        final compoundManagersByCompound =
            <String, List<CompoundManagerAssignment>>{};
        for (final assignment in compoundAssignments) {
          compoundManagersByCompound
              .putIfAbsent(assignment.compoundId, () => [])
              .add(assignment);
        }
        final directApartmentIds =
            apartmentAssignments.map((assignment) => assignment.apartmentId).toSet();
        final inheritedKeys = <String>{};
        final inheritedAssignments = <ApartmentManagerAssignment>[
          for (final apartment in portfolio.apartments)
            if (!directApartmentIds.contains(apartment.id))
              for (final manager
                  in compoundManagersByCompound[apartment.compoundId] ??
                      const <CompoundManagerAssignment>[])
                if (inheritedKeys
                    .add('${apartment.id}|${manager.managerId}'))
                  ApartmentManagerAssignment(
                    apartmentId: apartment.id,
                    managerId: manager.managerId,
                    fullName: manager.fullName,
                    phoneNumber: manager.phoneNumber,
                    unitLabel: apartment.label,
                    compoundId: apartment.compoundId ?? manager.compoundId,
                    compoundName: apartment.compoundName ??
                        compoundNames[manager.compoundId] ??
                        'عقار',
                  ),
        ];
        final effectiveAssignments = [
          ...apartmentAssignments,
          ...inheritedAssignments,
        ];
        final coveredUnits = effectiveAssignments
            .map((assignment) => assignment.apartmentId)
            .toSet()
            .length;
        final coverage =
            totalUnits == 0 ? 0 : (coveredUnits / totalUnits * 100).round();

        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () => _refresh(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              WebPageHeader(
                title: 'إدارة المديرين',
                subtitle:
                    'عيّن مديراً لعقار كامل أو لشقة محددة في ${country.name(english: I18n.isEnglish)}، وراجع التغطية الحالية',
                actions: [
                  OutlinedButton.icon(
                    onPressed: () => _refresh(ref),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('تحديث'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _assignCompound(context, ref, portfolio),
                    icon: const Icon(Icons.apartment_rounded, size: 18),
                    label: const Text('تعيين مدير عقار'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              WebKpiGrid(
                children: [
                  WebKpiCard(
                    label: 'مديرو العقارات',
                    value: '${compoundAssignments.length}',
                    icon: Icons.location_city_rounded,
                    color: AppColors.gold,
                    caption: 'تعيينات نشطة',
                  ),
                  WebKpiCard(
                    label: 'مديرو الشقق',
                    value: '${apartmentAssignments.length}',
                    icon: Icons.meeting_room_rounded,
                    color: AppColors.info,
                    caption: '$coveredUnits من $totalUnits وحدة مغطاة',
                  ),
                  WebKpiCard(
                    label: 'إجمالي المديرين',
                    value: '${managers.length}',
                    icon: Icons.support_agent_rounded,
                    color: AppColors.reserved,
                    caption: 'في هذه الدولة',
                  ),
                  WebKpiCard(
                    label: 'تغطية الشقق',
                    value: '$coverage%',
                    icon: Icons.verified_rounded,
                    color: coverage == 100
                        ? AppColors.occupied
                        : AppColors.pending,
                    caption: '$coveredUnits من $totalUnits شقة',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (compoundsAsync.isLoading || apartmentsAsync.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  ),
                ),
              WebPanel(
                title: 'مديرو العقارات',
                subtitle: 'المدير المسؤول عن كل وحدات العقار',
                action: TextButton.icon(
                  onPressed: () => _assignCompound(context, ref, portfolio),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('تعيين'),
                ),
                child: WebTable(
                  empty: const WebEmpty(
                    icon: Icons.location_city_rounded,
                    title: 'لا يوجد مديرون معيّنون على العقارات',
                    message: 'عيّن مديراً لعقار كامل ليتابع طلباته ومستأجريه.',
                  ),
                  columns: const [
                    WebTableColumn('العقار', flex: 3),
                    WebTableColumn('المدير', flex: 3),
                    WebTableColumn('الهاتف', flex: 2),
                    WebTableColumn('إجراء', flex: 1, align: TextAlign.center),
                  ],
                  rows: compoundAssignments
                      .map(
                        (assignment) => [
                          Text(
                            compoundNames[assignment.compoundId] ?? 'عقار',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Row(
                            children: [
                              AppAvatar(name: assignment.fullName, size: 32),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  assignment.fullName,
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
                          ),
                          Text(
                            prettyPhone(assignment.phoneNumber),
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          WebRowAction(
                            icon: Icons.person_remove_alt_1_rounded,
                            tooltip: tr('إزالة التعيين'),
                            color: AppColors.danger,
                            onTap: () => _removeCompound(context, ref, assignment),
                          ),
                        ],
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              WebPanel(
                title: 'مديرو الشقق',
                subtitle:
                    'كل وحدة مع مديرها الفعلي: التعيين المباشر يسبق مدير العقار',
                action: TextButton.icon(
                  onPressed: () => _assignApartment(context, ref, portfolio),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('تعيين'),
                ),
                child: WebTable(
                  empty: const WebEmpty(
                    icon: Icons.meeting_room_rounded,
                    title: 'لا توجد تغطية إدارية للشقق',
                    message:
                        'عيّن مديراً لعقار كامل لتغطية كل وحداته أو استخدم «تعيين» لشقة محددة.',
                  ),
                  columns: const [
                    WebTableColumn('العقار', flex: 2),
                    WebTableColumn('الوحدة', flex: 3),
                    WebTableColumn('المدير', flex: 3),
                    WebTableColumn('الهاتف', flex: 2),
                    WebTableColumn('إجراء', flex: 1, align: TextAlign.center),
                  ],
                  rows: effectiveAssignments
                      .map(
                        (assignment) => [
                          Text(
                            assignment.compoundName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  assignment.unitLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (inheritedKeys.contains(
                                  '${assignment.apartmentId}|${assignment.managerId}'))
                                const StatusPill(
                                  label: 'عبر العقار',
                                  color: AppColors.gold,
                                  compact: true,
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              AppAvatar(name: assignment.fullName, size: 32),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  assignment.fullName,
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
                          ),
                          Text(
                            prettyPhone(assignment.phoneNumber),
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          inheritedKeys.contains(
                                  '${assignment.apartmentId}|${assignment.managerId}')
                              ? const Tooltip(
                                  message:
                                      'يُدار تلقائياً عبر تعيين مدير العقار — أزل تعيين العقار لإيقافه',
                                  child: Icon(
                                    Icons.link_rounded,
                                    size: 18,
                                    color: AppColors.textMuted,
                                  ),
                                )
                              : WebRowAction(
                                  icon: Icons.person_remove_alt_1_rounded,
                                  tooltip: tr('إزالة التعيين'),
                                  color: AppColors.danger,
                                  onTap: () =>
                                      _removeApartment(context, ref, assignment),
                                ),
                        ],
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: .05),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.gold.withValues(alpha: .15)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.gold, size: 18),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'الأولوية: مدير الشقة يتولى طلبات وحدته فقط، ثم مدير العقار يتولى بقية وحدات العقار. عند تعيين أكثر من مدير لعقار واحد يصل الطلب لكل مديري العقار.',
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
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _assignCompound(
    BuildContext context,
    WidgetRef ref,
    Portfolio portfolio,
  ) async {
    if (portfolio.compounds.isEmpty) {
      showError(context, 'لا توجد عقارات مسجلة بعد');
      return;
    }
    final assigned = await showDialog<bool>(
      context: context,
      builder: (_) => _AssignCompoundDialog(
        repository: ref.read(repositoryProvider),
        compounds: portfolio.compounds,
      ),
    );
    if (assigned == true && context.mounted) {
      ref.invalidate(compoundManagersProvider);
      ref.invalidate(ownerDashboardProvider);
      showSuccess(context, 'تم تعيين مدير العقار');
    }
  }

  Future<void> _assignApartment(
    BuildContext context,
    WidgetRef ref,
    Portfolio portfolio,
  ) async {
    if (portfolio.compounds.isEmpty) {
      showError(context, 'لا توجد عقارات مسجلة بعد');
      return;
    }
    final assigned = await showDialog<bool>(
      context: context,
      builder: (_) => _AssignApartmentDialog(
        repository: ref.read(repositoryProvider),
        compounds: portfolio.compounds,
      ),
    );
    if (assigned == true && context.mounted) {
      ref.invalidate(apartmentManagersProvider);
      ref.invalidate(ownerDashboardProvider);
      showSuccess(context, 'تم تعيين مدير الشقة');
    }
  }

  Future<void> _removeCompound(
    BuildContext context,
    WidgetRef ref,
    CompoundManagerAssignment assignment,
  ) async {
    final confirmed = await _confirmRemove(
      context,
      title: 'إزالة مدير العقار',
      message:
          'هل تريد إزالة تعيين ${assignment.fullName} عن هذا العقار؟ لن يتمكن من رؤية طلباته بعد ذلك.',
    );
    if (!confirmed) return;
    try {
      await ref.read(repositoryProvider).removeManager(
            compoundId: assignment.compoundId,
            managerId: assignment.managerId,
          );
      ref.invalidate(compoundManagersProvider);
      ref.invalidate(ownerDashboardProvider);
      if (context.mounted) showSuccess(context, 'تم إزالة التعيين');
    } catch (error) {
      if (context.mounted) showError(context, friendlyError(error));
    }
  }

  Future<void> _removeApartment(
    BuildContext context,
    WidgetRef ref,
    ApartmentManagerAssignment assignment,
  ) async {
    final confirmed = await _confirmRemove(
      context,
      title: 'إزالة مدير الشقة',
      message:
          'هل تريد إزالة تعيين ${assignment.fullName} عن ${assignment.unitLabel}؟',
    );
    if (!confirmed) return;
    try {
      await ref.read(repositoryProvider).removeApartmentManager(
            apartmentId: assignment.apartmentId,
            managerId: assignment.managerId,
          );
      ref.invalidate(apartmentManagersProvider);
      ref.invalidate(ownerDashboardProvider);
      if (context.mounted) showSuccess(context, 'تم إزالة التعيين');
    } catch (error) {
      if (context.mounted) showError(context, friendlyError(error));
    }
  }

  Future<bool> _confirmRemove(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
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
            child: const Text('إزالة', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    return result == true;
  }
}

class _AssignCompoundDialog extends StatefulWidget {
  const _AssignCompoundDialog({
    required this.repository,
    required this.compounds,
  });

  final SupabaseRepository repository;
  final List<Compound> compounds;

  @override
  State<_AssignCompoundDialog> createState() => _AssignCompoundDialogState();
}

class _AssignCompoundDialogState extends State<_AssignCompoundDialog> {
  late String _compoundId = widget.compounds.first.id;
  final _phone = TextEditingController();
  bool _loading = false;
  String? _error;

  Compound get _compound =>
      widget.compounds.firstWhere((compound) => compound.id == _compoundId);

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phone.text.trim();
    final country = _compound.country;
    if (!country.isValidPhone(phone)) {
      setState(() => _error =
          'أدخل رقماً صحيحاً لـ${country.nameAr} (${country.phoneHint})');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.assignManager(
        compoundId: _compoundId,
        phone: phone,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyError(error);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعيين مدير لعقار'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _compoundId,
                isExpanded: true,
                dropdownColor: AppColors.navy800,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  labelText: tr('العقار'),
                  prefixIcon: Icon(Icons.location_city_rounded),
                ),
                items: widget.compounds
                    .map(
                      (compound) => DropdownMenuItem(
                        value: compound.id,
                        child: Text(
                          compound.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _loading
                    ? null
                    : (value) => setState(() => _compoundId = value ?? _compoundId),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _phone,
                enabled: !_loading,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: tr('رقم هاتف المدير'),
                  hintText: _compound.country.phoneHint,
                  prefixIcon: const Icon(Icons.phone_iphone_rounded),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    height: 1.5,
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
        TextButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('تعيين'),
        ),
      ],
    );
  }
}

class _AssignApartmentDialog extends StatefulWidget {
  const _AssignApartmentDialog({
    required this.repository,
    required this.compounds,
  });

  final SupabaseRepository repository;
  final List<Compound> compounds;

  @override
  State<_AssignApartmentDialog> createState() =>
      _AssignApartmentDialogState();
}

class _AssignApartmentDialogState extends State<_AssignApartmentDialog> {
  late String _compoundId = widget.compounds.first.id;
  String? _buildingId;
  String? _apartmentId;
  final _phone = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final compound = widget.compounds.first;
    if (compound.buildings.isNotEmpty) {
      _buildingId = compound.buildings.first.id;
      final apartments = compound.buildings.first.apartments;
      if (apartments.isNotEmpty) _apartmentId = apartments.first.id;
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Compound get _compound =>
      widget.compounds.firstWhere((compound) => compound.id == _compoundId);

  Building? get _building {
    final id = _buildingId;
    if (id == null) return null;
    for (final building in _compound.buildings) {
      if (building.id == id) return building;
    }
    return null;
  }

  Future<void> _submit() async {
    final apartmentId = _apartmentId;
    if (apartmentId == null) {
      setState(() => _error = 'اختر الشقة المطلوبة');
      return;
    }
    final phone = _phone.text.trim();
    final country = _compound.country;
    if (!country.isValidPhone(phone)) {
      setState(() => _error =
          'أدخل رقماً صحيحاً لـ${country.nameAr} (${country.phoneHint})');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.assignApartmentManager(
        apartmentId: apartmentId,
        phone: phone,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyError(error);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final building = _building;
    final apartments = building?.apartments ?? const <Apartment>[];
    return AlertDialog(
      title: const Text('تعيين مدير لشقة'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _compoundId,
                isExpanded: true,
                dropdownColor: AppColors.navy800,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  labelText: tr('العقار'),
                  prefixIcon: Icon(Icons.location_city_rounded),
                ),
                items: widget.compounds
                    .map(
                      (compound) => DropdownMenuItem(
                        value: compound.id,
                        child: Text(
                          compound.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _loading
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _compoundId = value;
                          final compound = widget.compounds
                              .firstWhere((item) => item.id == value);
                          _buildingId = compound.buildings.isEmpty
                              ? null
                              : compound.buildings.first.id;
                          _apartmentId = (compound.buildings.isEmpty ||
                                  compound.buildings.first.apartments.isEmpty)
                              ? null
                              : compound.buildings.first.apartments.first.id;
                        });
                      },
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                value: _buildingId,
                isExpanded: true,
                dropdownColor: AppColors.navy800,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  labelText: tr('العمارة'),
                  prefixIcon: Icon(Icons.apartment_rounded),
                ),
                items: _compound.buildings
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: _loading
                    ? null
                    : (value) {
                        setState(() {
                          _buildingId = value;
                          final selected = _compound.buildings
                              .where((item) => item.id == value)
                              .toList();
                          _apartmentId = (selected.isEmpty ||
                                  selected.first.apartments.isEmpty)
                              ? null
                              : selected.first.apartments.first.id;
                        });
                      },
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                value: apartments.any((item) => item.id == _apartmentId)
                    ? _apartmentId
                    : null,
                isExpanded: true,
                dropdownColor: AppColors.navy800,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  labelText: tr('الشقة'),
                  prefixIcon: Icon(Icons.meeting_room_rounded),
                ),
                items: apartments
                    .map(
                      (apartment) => DropdownMenuItem(
                        value: apartment.id,
                        child: Text(
                          '${apartment.displayName} · ${apartment.status.label}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _loading
                    ? null
                    : (value) => setState(() => _apartmentId = value),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _phone,
                enabled: !_loading,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: tr('رقم هاتف المدير'),
                  hintText: _compound.country.phoneHint,
                  prefixIcon: const Icon(Icons.phone_iphone_rounded),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    height: 1.5,
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
        TextButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('تعيين'),
        ),
      ],
    );
  }
}
