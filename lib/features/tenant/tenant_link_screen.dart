import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/system_insets.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';
import '../../core/i18n/i18n.dart';

class TenantLinkScreen extends ConsumerStatefulWidget {
  const TenantLinkScreen({
    super.key,
    required this.profile,
    this.pendingLease,
  });

  final AppProfile profile;
  final Lease? pendingLease;

  @override
  ConsumerState<TenantLinkScreen> createState() => _TenantLinkScreenState();
}

class _TenantLinkScreenState extends ConsumerState<TenantLinkScreen> {
  bool _busy = false;

  Future<void> _refresh() async {
    ref.invalidate(vacantPortfolioProvider);
    ref.invalidate(tenantSnapshotProvider);
    ref.invalidate(currentProfileProvider);
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.pendingLease;
    if (pending != null) return _buildPending(pending);

    final portfolioAsync = ref.watch(vacantPortfolioProvider);
    return PremiumScaffold(
      title: 'ربط الشقة',
      showBack: true,
      actions: [
        IconButton(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
        ),
      ],
      body: portfolioAsync.when(
        loading: () => const LoadingList(count: 3),
        error: (error, _) => ErrorView(message: friendlyError(error), onRetry: _refresh),
        data: (portfolio) {
          if (portfolio.total == 0) {
            return EmptyState(
              icon: Icons.meeting_room_outlined,
              title: 'لا توجد شقق فارغة حالياً',
              message: 'تواصل مع مدير العقارات لإضافة شقتك إلى حسابك، أو أعد المحاولة لاحقاً.',
              actionLabel: 'تحديث',
              onAction: _refresh,
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: [
              GlassCard(
                glowColor: AppColors.gold,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: .13),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(Icons.home_work_rounded, color: AppColors.gold, size: 22),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'اختر شقتك',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'اختر من الشقق الفارغة وسيتم إرسال طلب الربط للمدير',
                                style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.info.withValues(alpha: .22)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.info),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'بعد موافقة المدير ستظهر تفاصيل عقدك وموعد الإيجار في الصفحة الرئيسية.',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 10,
                                height: 1.6,
                                color: AppColors.info,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final compound in portfolio.compounds) ...[
                SectionHeader(
                  title: compound.name,
                  subtitle: compound.location,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (compound.buildings.isEmpty)
                  const EmptyState(icon: Icons.apartment_rounded, title: 'لا توجد شقق فارغة في هذا العقار')
                else
                  ...compound.buildings.map((building) => _BuildingSection(
                        building: building,
                        onSelect: _busy ? null : (apartment) => _openForm(apartment),
                      )),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildPending(Lease lease) {
    return PremiumScaffold(
      title: 'طلب ربط الشقة',
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          GlassCard(
            glowColor: AppColors.pending,
            borderColor: AppColors.pending.withValues(alpha: .30),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.pending.withValues(alpha: .12),
                    border: Border.all(color: AppColors.pending.withValues(alpha: .35)),
                  ),
                  child: const Icon(Icons.hourglass_top_rounded, color: AppColors.pending, size: 34),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'طلبك بانتظار موافقة المدير',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'تم إرسال طلب ربط الشقة بنجاح. سيتم تفعيل العقد بعد مراجعة المدير.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, height: 1.6, color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                InfoRow(icon: Icons.meeting_room_rounded, label: 'الشقة', value: lease.apartmentLabel ?? '—'),
                InfoRow(
                  icon: Icons.payments_rounded,
                  label: 'الإيجار الشهري',
                  value: formatMoney(lease.monthlyRent, withCurrency: true),
                  valueColor: AppColors.gold,
                ),
                InfoRow(icon: Icons.calendar_today_rounded, label: 'تاريخ البداية', value: formatDate(lease.startDate)),
                InfoRow(icon: Icons.event_available_rounded, label: 'تاريخ النهاية', value: formatDate(lease.endDate)),
                const SizedBox(height: AppSpacing.lg),
                GoldButton(
                  label: 'تحديث الحالة',
                  icon: Icons.refresh_rounded,
                  onPressed: _refresh,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openForm(Apartment apartment) async {
    final rentController = TextEditingController(text: apartment.rentAmount.toStringAsFixed(0));
    final depositController = TextEditingController();
    final notesController = TextEditingController();
    var startDate = DateTime.now();
    var months = 12;
    var loading = false;
    String? error;

    final submitted = await showModalBottomSheet<bool>(
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
                padding: withSystemBottomInset(context, const EdgeInsets.all(AppSpacing.lg)),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.home_work_rounded, color: AppColors.gold),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              apartment.label,
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 17,
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
                      Text(
                        [
                          if (apartment.compoundName != null) apartment.compoundName!,
                          if (apartment.buildingName != null) apartment.buildingName!,
                          if (apartment.floorLabel.isNotEmpty) apartment.floorLabel,
                        ].join(' · '),
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: rentController,
                        readOnly: true,
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.gold),
                        decoration: InputDecoration(
                          labelText: I18n.isEnglish
                              ? 'Monthly rent (${apartment.country.currencyCode})'
                              : 'الإيجار الشهري (${apartment.country.currencyCode})',
                          prefixIcon: Icon(Icons.payments_rounded),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: depositController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: tr('التأمين (اختياري)'),
                          prefixIcon: Icon(Icons.savings_rounded),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                            locale: Locale(I18n.language.name),
                          );
                          if (picked != null) setSheetState(() => startDate = picked);
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
                                'تاريخ بداية العقد',
                                style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const Spacer(),
                              Text(
                                formatDate(startDate),
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
                      Row(
                        children: [
                          const Text(
                            'مدة العقد',
                            style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 6,
                              runSpacing: 6,
                              children: [1, 3, 6, 12].map(
                                (value) => ChoiceChip(
                                  label: Text(leaseDurationLabel(value)),
                                  selected: months == value,
                                  onSelected: (_) => setSheetState(() => months = value),
                                  selectedColor: AppColors.gold,
                                  backgroundColor: Colors.white.withValues(alpha: .04),
                                  labelStyle: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: months == value ? AppColors.navy900 : AppColors.textSecondary,
                                  ),
                                  side: BorderSide(
                                    color: months == value ? AppColors.gold : Colors.white.withValues(alpha: .08),
                                  ),
                                ),
                              ).toList(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: tr('ملاحظات للمدير (اختياري)'),
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
                        label: 'إرسال طلب الربط',
                        icon: Icons.send_rounded,
                        loading: loading,
                        onPressed: () async {
                          setSheetState(() {
                            loading = true;
                            error = null;
                          });
                          try {
                            final endDate = addMonthsClamped(startDate, months);
                            await ref.read(repositoryProvider).requestTenantLink(
                                  tenant: widget.profile,
                                  apartment: apartment,
                                  monthlyRent: double.tryParse(rentController.text) ?? apartment.rentAmount,
                                  startDate: startDate,
                                  endDate: endDate,
                                  deposit: double.tryParse(depositController.text) ?? 0,
                                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                                );
                            ref.invalidate(tenantSnapshotProvider);
                            ref.invalidate(managerSnapshotProvider);
                            ref.invalidate(ownerSnapshotProvider);
                            ref.invalidate(vacantPortfolioProvider);
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
    rentController.dispose();
    depositController.dispose();
    notesController.dispose();
    if (submitted == true) {
      if (!mounted) return;
      showSuccess(context, 'تم إرسال طلب الربط إلى مدير العقارات');
      setState(() => _busy = false);
      _refresh();
    }
  }
}

class _BuildingSection extends StatelessWidget {
  const _BuildingSection({required this.building, required this.onSelect});

  final Building building;
  final ValueChanged<Apartment>? onSelect;

  @override
  Widget build(BuildContext context) {
    final vacant = building.apartments.where((a) => a.status == ApartmentStatus.vacant).toList();
    if (vacant.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.apartment_rounded, color: AppColors.gold, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    building.name,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                StatusPill(label: '${vacant.length} شقة فارغة', color: AppColors.occupied, compact: true),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ...building.floors.where((floor) => floor.apartments.any((a) => a.status == ApartmentStatus.vacant)).map(
              (floor) {
                final units = floor.apartments.where((a) => a.status == ApartmentStatus.vacant).toList();
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        floor.apartments.isNotEmpty
                            ? floor.apartments.first.floorLabel
                            : 'الطابق ${floor.floorNumber}',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: units.map((apartment) {
                          return GestureDetector(
                            onTap: onSelect == null ? null : () => onSelect!(apartment),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                border: Border.all(color: AppColors.gold.withValues(alpha: .30)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    apartment.displayName,
                                    style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${formatMoney(apartment.rentAmount, compact: true, country: apartment.country)} / شهرياً',
                                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 9, color: AppColors.gold),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
