import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/contact.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';
import '../manager/add_tenant_screen.dart';
import '../shared/request_card.dart';
import '../shared/request_detail_screen.dart';

class ApartmentDetailsScreen extends ConsumerStatefulWidget {
  const ApartmentDetailsScreen({
    super.key,
    required this.apartmentId,
    required this.viewer,
    this.portfolio,
  });

  final String apartmentId;
  final AppProfile viewer;
  final Portfolio? portfolio;

  @override
  ConsumerState<ApartmentDetailsScreen> createState() => _ApartmentDetailsScreenState();
}

class _ApartmentDetailsScreenState extends ConsumerState<ApartmentDetailsScreen> {
  Apartment? _apartment;
  AppProfile? _tenant;
  Lease? _lease;
  AppProfile? _manager;
  AppProfile? _owner;
  List<MaintenanceRequest> _requests = const [];
  List<Payment> _payments = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(repositoryProvider);
      final apartment = await repo.apartmentById(widget.apartmentId);
      if (apartment == null) throw Exception('لم يتم العثور على الشقة');
      final tenant = await repo.currentTenantForApartment(apartment.id);
      final lease = await repo.activeLeaseForApartment(apartment.id);
      final requests = await repo.requestsForApartment(apartment.id);
      final payments = tenant == null ? <Payment>[] : await repo.paymentsForTenant(tenant.id);
      AppProfile? manager;
      AppProfile? owner;
      if (apartment.compoundId != null) {
        manager = await repo.managerForApartment(
          apartment.id,
          compoundId: apartment.compoundId,
        );
        owner = await repo.ownerForCompound(apartment.compoundId!);
      }
      if (!mounted) return;
      setState(() {
        _apartment = apartment;
        _tenant = tenant;
        _lease = lease;
        _requests = requests;
        _payments = payments;
        _manager = manager;
        _owner = owner;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'تفاصيل الشقة',
      body: _loading
          ? const LoadingList(count: 4)
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final apartment = _apartment!;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.gold,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          _buildHero(apartment),
          const SizedBox(height: AppSpacing.md),
          _buildTenantCard(),
          const SizedBox(height: AppSpacing.md),
          _buildLeaseCard(),
          const SizedBox(height: AppSpacing.md),
          _buildMaintenance(),
          const SizedBox(height: AppSpacing.md),
          _buildPayments(),
        ],
      ),
    );
  }

  Widget _buildHero(Apartment apartment) {
    final color = switch (apartment.status) {
      ApartmentStatus.occupied => AppColors.occupied,
      ApartmentStatus.vacant => AppColors.vacant,
      ApartmentStatus.maintenance => AppColors.pending,
      ApartmentStatus.reserved => AppColors.reserved,
    };
    return GlassCard(
      glowColor: color,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color.withValues(alpha: .25)),
                ),
                child: Icon(apartment.status.icon, color: color, size: 26),
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
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (apartment.compoundName != null) apartment.compoundName!,
                        if (apartment.buildingName != null) apartment.buildingName!,
                        if (apartment.floorLabel.isNotEmpty) apartment.floorLabel,
                      ].join(' · '),
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              StatusPill(label: apartment.status.label, color: color, compact: true),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _HeroMetric(label: 'الغرف', value: '${apartment.roomCount}'),
              _HeroMetric(label: 'المساحة', value: apartment.areaSqm == null ? '—' : '${apartment.areaSqm!.round()} م²'),
              _HeroMetric(label: 'الإيجار', value: formatMoney(apartment.rentAmount, compact: true), color: AppColors.gold),
            ],
          ),
          if (widget.viewer.role == UserRole.manager && apartment.status == ApartmentStatus.vacant) ...[
            const SizedBox(height: AppSpacing.lg),
            GoldButton(
              label: 'إضافة مستأجر لهذه الشقة',
              icon: Icons.person_add_alt_1_rounded,
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddTenantScreen(
                      manager: widget.viewer,
                      portfolio: widget.portfolio,
                      initialApartment: apartment,
                    ),
                  ),
                );
                _load();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTenantCard() {
    final tenant = _tenant;
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'المستأجر الحالي', subtitle: 'بيانات التواصل والملف'),
          const SizedBox(height: AppSpacing.md),
          if (tenant == null)
            const Text(
              'لا يوجد مستأجر مسجل لهذه الشقة حالياً.',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textMuted),
            )
          else ...[
            Row(
              children: [
                AppAvatar(name: tenant.displayName, imageUrl: tenant.avatarUrl, size: 48),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenant.displayName,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        prettyPhone(tenant.phoneNumber),
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const StatusPill(label: 'نشط', color: AppColors.occupied, compact: true),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            contactActions(
              context: context,
              phone: tenant.phoneNumber,
              message:
                  'مرحباً ${tenant.displayName}، بخصوص ${_apartment?.displayName ?? 'الشقة'}',
              color: AppColors.occupied,
            ),
          ],
          const Divider(height: AppSpacing.lg),
          const SectionHeader(title: 'جهة الإدارة', subtitle: 'المسؤول عن المبنى'),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _ContactPerson(
                  label: 'مدير العقارات',
                  profile: _manager,
                  icon: Icons.support_agent_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ContactPerson(
                  label: 'المالك',
                  profile: _owner,
                  icon: Icons.workspace_premium_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaseCard() {
    final lease = _lease;
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'عقد الإيجار', subtitle: 'التفاصيل المالية والزمنية'),
          const SizedBox(height: AppSpacing.md),
          if (lease == null)
            const Text(
              'لا يوجد عقد نشط.',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textMuted),
            )
          else ...[
            InfoRow(icon: Icons.calendar_today_rounded, label: 'بداية العقد', value: formatDate(lease.startDate)),
            InfoRow(icon: Icons.event_available_rounded, label: 'نهاية العقد', value: formatDate(lease.endDate)),
            InfoRow(
              icon: Icons.payments_rounded,
              label: 'الإيجار الشهري',
              value: formatMoney(lease.monthlyRent, withCurrency: true),
              valueColor: AppColors.gold,
            ),
            InfoRow(
              icon: Icons.savings_rounded,
              label: 'التأمين',
              value: formatMoney(lease.depositAmount, withCurrency: true),
            ),
            InfoRow(
              icon: Icons.verified_user_rounded,
              label: 'حالة العقد',
              value: lease.isActive ? 'نشط' : lease.isPending ? 'بانتظار الموافقة' : lease.status,
              valueColor: lease.isActive ? AppColors.occupied : AppColors.pending,
            ),
            if (lease.notes != null)
              InfoRow(icon: Icons.notes_rounded, label: 'ملاحظات', value: lease.notes!),
          ],
        ],
      ),
    );
  }

  Widget _buildMaintenance() {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'طلبات الصيانة',
            subtitle: '${_requests.length} طلب مسجل',
          ),
          const SizedBox(height: AppSpacing.md),
          if (_requests.isEmpty)
            const Text(
              'لا توجد طلبات صيانة لهذه الشقة.',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textMuted),
            )
          else
            ..._requests.take(4).map(
                  (request) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: RequestCard(
                      request: request,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RequestDetailScreen(
                            requestId: request.id,
                            viewer: widget.viewer,
                            contact: _manager ?? _owner,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildPayments() {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'سجل المدفوعات', subtitle: 'آخر الدفعات المسجلة'),
          const SizedBox(height: AppSpacing.md),
          if (_payments.isEmpty)
            const Text(
              'لا توجد مدفوعات مسجلة.',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textMuted),
            )
          else
            ..._payments.take(5).map(
                  (payment) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.occupied.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.check_rounded, size: 17, color: AppColors.occupied),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatMoney(payment.amount, withCurrency: true),
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '${formatDate(payment.paymentDate)} · ${payment.methodLabel}',
                                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value, this.color = AppColors.textPrimary});

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
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ContactPerson extends StatelessWidget {
  const _ContactPerson({required this.label, required this.profile, required this.icon});

  final String label;
  final AppProfile? profile;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .03),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.gold),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            profile?.displayName ?? 'غير محدد',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (profile != null) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => openPhoneCall(profile!.phoneNumber),
              child: const Icon(Icons.call_rounded, size: 15, color: AppColors.occupied),
            ),
          ],
        ],
      ),
    );
  }
}
