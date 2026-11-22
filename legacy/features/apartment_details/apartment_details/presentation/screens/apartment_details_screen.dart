import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:the_city_property/core/theme/app_colors.dart';
import 'package:the_city_property/core/theme/app_spacing.dart';
import 'package:the_city_property/core/widgets/glass_card.dart';

class ApartmentDetailsScreen extends ConsumerStatefulWidget {
  final String apartmentId;
  
  const ApartmentDetailsScreen({
    super.key,
    required this.apartmentId,
  });

  @override
  ConsumerState<ApartmentDetailsScreen> createState() => _ApartmentDetailsScreenState();
}

class _ApartmentDetailsScreenState extends ConsumerState<ApartmentDetailsScreen> {
  Map<String, dynamic>? _apartment;
  Map<String, dynamic>? _tenant;
  Map<String, dynamic>? _lease;
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _maintenanceRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApartmentDetails();
  }

  Future<void> _loadApartmentDetails() async {
    try {
      // جلب معلومات الشقة
      final apartmentData = await Supabase.instance.client
          .from('apartments')
          .select('*, floors(building_id, floor_number, buildings(name, compounds(name)))')
          .eq('id', widget.apartmentId)
          .single();

      // جلب المستأجر الحالي
      final tenantData = await Supabase.instance.client
          .from('tenant_apartments')
          .select('profiles:tenant_id(id, full_name, phone_number, email)')
          .eq('apartment_id', widget.apartmentId)
          .eq('is_current', true)
          .maybeSingle();

      // جلب العقد النشط
      final leaseData = await Supabase.instance.client
          .from('leases')
          .select()
          .eq('apartment_id', widget.apartmentId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      // جلب سجل المدفوعات
      final paymentsData = await Supabase.instance.client
          .from('payments')
          .select()
          .eq('apartment_id', widget.apartmentId)
          .order('payment_date', ascending: false);

      // جلب طلبات الصيانة
      final maintenanceData = await Supabase.instance.client
          .from('maintenance_requests')
          .select()
          .eq('apartment_id', widget.apartmentId)
          .order('created_at', ascending: false)
          .limit(5);

      setState(() {
        _apartment = apartmentData;
        _tenant = tenantData?['profiles'];
        _lease = leaseData;
        _payments = List<Map<String, dynamic>>.from(paymentsData);
        _maintenanceRequests = List<Map<String, dynamic>>.from(maintenanceData);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading apartment details: ' + e.toString());
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.navy800,
        appBar: AppBar(title: const Text('جاري التحميل...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_apartment == null) {
      return Scaffold(
        backgroundColor: AppColors.navy800,
        appBar: AppBar(title: const Text('خطأ')),
        body: const Center(child: Text('لم يتم العثور على الشقة')),
      );
    }

    final floorData = _apartment!['floors'] as Map<String, dynamic>?;
    final buildingData = floorData?['buildings'] as Map<String, dynamic>?;
    final compoundData = buildingData?['compounds'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: AppColors.navy800,
      appBar: AppBar(
        title: const Text('تفاصيل الشقة', style: TextStyle(fontFamily: 'Tajawal')),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: تعديل معلومات الشقة
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // معلومات الشقة الأساسية
            _buildInfoSection(),
            const SizedBox(height: AppSpacing.lg),
            
            // معلومات المستأجر
            if (_tenant != null) _buildTenantSection(),
            const SizedBox(height: AppSpacing.lg),
            
            // معلومات العقد
            if (_lease != null) _buildLeaseSection(),
            const SizedBox(height: AppSpacing.lg),
            
            // سجل المدفوعات
            _buildPaymentsSection(),
            const SizedBox(height: AppSpacing.lg),
            
            // طلبات الصيانة
            _buildMaintenanceSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    final unitNumber = _apartment!['unit_number'] ?? '';
    final floorNumber = _apartment!['floors']?['floor_number'] ?? '';
    final buildingName = _apartment!['floors']?['buildings']?['name'] ?? '';
    final compoundName = _apartment!['floors']?['buildings']?['compounds']?['name'] ?? '';
    final status = _apartment!['status'] ?? '';
    final rentAmount = _apartment!['rent_amount'] ?? 0;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'occupied':
        statusColor = AppColors.occupied;
        statusText = 'مؤجرة';
        statusIcon = Icons.check_circle;
        break;
      case 'vacant':
        statusColor = AppColors.vacant;
        statusText = 'فارغة';
        statusIcon = Icons.home_outlined;
        break;
      case 'maintenance':
        statusColor = AppColors.pending;
        statusText = 'صيانة';
        statusIcon = Icons.build;
        break;
      default:
        statusColor = AppColors.textMuted;
        statusText = 'غير معروف';
        statusIcon = Icons.help;
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.apartment, color: AppColors.gold, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'شقة ',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: statusColor, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 16),
                    const SizedBox(width: AppSpacing.xs),
                    Text(statusText, style: TextStyle(color: statusColor, fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildInfoRow(Icons.location_city, compoundName),
          _buildInfoRow(Icons.business, buildingName),
          _buildInfoRow(Icons.layers, 'طابق '),
          _buildInfoRow(Icons.attach_money, ' دينار/شهرياً'),
        ],
      ),
    );
  }

  Widget _buildTenantSection() {
    final tenantName = _tenant?['full_name'] ?? '';
    final tenantPhone = _tenant?['phone_number'] ?? '';

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person, color: AppColors.gold, size: 24),
              SizedBox(width: AppSpacing.sm),
              Text(
                'معلومات المستأجر',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: 'Tajawal',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildInfoRow(Icons.person_outline, tenantName),
          _buildInfoRow(Icons.phone, tenantPhone),
        ],
      ),
    );
  }

  Widget _buildLeaseSection() {
    final startDate = _lease?['start_date'] ?? '';
    final endDate = _lease?['end_date'] ?? '';
    final monthlyRent = _lease?['monthly_rent'] ?? 0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.description, color: AppColors.gold, size: 24),
              SizedBox(width: AppSpacing.sm),
              Text(
                'تفاصيل العقد',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: 'Tajawal',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildInfoRow(Icons.calendar_today, 'بداية: '),
          _buildInfoRow(Icons.event_available, 'نهاية: '),
          _buildInfoRow(Icons.attach_money, ' دينار/شهرياً'),
        ],
      ),
    );
  }

  Widget _buildPaymentsSection() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payment, color: AppColors.gold, size: 24),
              SizedBox(width: AppSpacing.sm),
              Text(
                'سجل المدفوعات',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: 'Tajawal',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_payments.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text('لا توجد مدفوعات مسجلة', style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal')),
              ),
            )
          else
            ..._payments.map((payment) => _buildPaymentItem(payment)),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(Map<String, dynamic> payment) {
    final amount = payment['amount'] ?? 0;
    final date = payment['payment_date'] ?? '';
    final method = payment['payment_method'] ?? 'غير محدد';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.occupied.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.check_circle, color: AppColors.occupied, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(' دينار', style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.xs),
                Text(date, style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
              ],
            ),
          ),
          Text(method, style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMaintenanceSection() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.build, color: AppColors.gold, size: 24),
              SizedBox(width: AppSpacing.sm),
              Text(
                'طلبات الصيانة',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: 'Tajawal',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_maintenanceRequests.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text('لا توجد طلبات صيانة', style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal')),
              ),
            )
          else
            ..._maintenanceRequests.map((request) => _buildMaintenanceItem(request)),
        ],
      ),
    );
  }

  Widget _buildMaintenanceItem(Map<String, dynamic> request) {
    final title = request['title'] ?? '';
    final status = request['status'] ?? '';
    final date = request['created_at'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(status, style: TextStyle(color: AppColors.pending, fontFamily: 'Tajawal', fontSize: 12)),
              const SizedBox(width: AppSpacing.sm),
              Text(date, style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Text(text, style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 14)),
        ],
      ),
    );
  }
}
