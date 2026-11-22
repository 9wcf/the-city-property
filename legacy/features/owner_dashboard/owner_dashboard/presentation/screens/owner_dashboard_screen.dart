import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:the_city_property/core/theme/app_colors.dart';
import 'package:the_city_property/core/theme/app_spacing.dart';
import 'package:the_city_property/core/widgets/glass_card.dart';
import 'package:the_city_property/features/apartment_details/presentation/screens/apartment_details_screen.dart';

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  ConsumerState<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> {
  List<Map<String, dynamic>> _compounds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final profileData = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('role', 'owner')
          .limit(1)
          .maybeSingle();

      if (profileData == null) {
        print('No owner found in database');
        setState(() => _isLoading = false);
        return;
      }

      final ownerId = profileData['id'] as String;
      print('Loading data for owner: ' + ownerId);

      final data = await Supabase.instance.client
          .from('compounds')
          .select('*, buildings(*, floors(*, apartments(*)))')
          .eq('owner_id', ownerId);

      print('Loaded ' + data.length.toString() + ' compounds');

      setState(() {
        _compounds = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: ' + e.toString());
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy800,
      appBar: AppBar(
        title: const Text('لوحة التحكم', style: TextStyle(fontFamily: 'Tajawal')),
        actions: [
          IconButton(icon: const Icon(Icons.notifications), onPressed: () {}),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCards(),
                    const SizedBox(height: AppSpacing.xl),
                    const Text(
                      'المجمعات السكنية',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.gold, fontFamily: 'Tajawal'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_compounds.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            children: [
                              Icon(Icons.business_outlined, size: 64, color: AppColors.textMuted),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'لا توجد مجمعات مضافة حالياً.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._compounds.map((compound) => _buildCompoundCard(compound)),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/add-tenant');
        },
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navy900,
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة مستأجر', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('مؤجرة', '24', AppColors.occupied, Icons.check_circle)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _buildStatCard('فارغة', '6', AppColors.vacant, Icons.home_outlined)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _buildStatCard('صيانة', '3', AppColors.pending, Icons.build)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return GlassCard(
      glowColor: color,
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal')),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color, fontFamily: 'Tajawal')),
        ],
      ),
    );
  }

  Widget _buildCompoundCard(Map<String, dynamic> compound) {
    final buildings = List<Map<String, dynamic>>.from(compound['buildings'] ?? []);
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_city, color: AppColors.gold, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(compound['name'] as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Tajawal'))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(color: AppColors.occupied.withOpacity(0.2), borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Text(buildings.length.toString() + ' عمارة', style: const TextStyle(color: AppColors.occupied, fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...buildings.map((building) => _buildBuildingCard(building)),
        ],
      ),
    );
  }

  Widget _buildBuildingCard(Map<String, dynamic> building) {
    final floors = List<Map<String, dynamic>>.from(building['floors'] ?? []);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.navy700, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.navy600)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.apartment, color: AppColors.gold, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Text(building['name'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Tajawal')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...floors.map((floor) => _buildFloorCard(floor)),
        ],
      ),
    );
  }

  Widget _buildFloorCard(Map<String, dynamic> floor) {
    final apartments = List<Map<String, dynamic>>.from(floor['apartments'] ?? []);
    final floorNum = floor['floor_number'].toString();
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(color: AppColors.navy800, borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('طابق ' + floorNum, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: apartments.map((apt) => _buildApartmentChip(apt)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildApartmentChip(Map<String, dynamic> apartment) {
    final status = apartment['status'] as String;
    final apartmentId = apartment['id'] as String;
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'occupied': statusColor = AppColors.occupied; statusIcon = Icons.check_circle; break;
      case 'vacant': statusColor = AppColors.vacant; statusIcon = Icons.home_outlined; break;
      case 'maintenance': statusColor = AppColors.pending; statusIcon = Icons.build; break;
      default: statusColor = AppColors.textMuted; statusIcon = Icons.help;
    }
    final unitNum = apartment['unit_number'] as String;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ApartmentDetailsScreen(apartmentId: apartmentId),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: statusColor, width: 1.5)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusIcon, color: statusColor, size: 16),
            const SizedBox(width: AppSpacing.xs),
            Text(unitNum, style: TextStyle(color: statusColor, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}