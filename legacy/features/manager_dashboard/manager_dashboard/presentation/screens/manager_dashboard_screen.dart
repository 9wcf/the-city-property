import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:the_city_property/core/theme/app_colors.dart';
import 'package:the_city_property/core/theme/app_spacing.dart';
import 'package:the_city_property/core/widgets/glass_card.dart';

class ManagerDashboardScreen extends ConsumerStatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  ConsumerState<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends ConsumerState<ManagerDashboardScreen> {
  List<Map<String, dynamic>> _assignedCompounds = [];
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
          .eq('role', 'manager')
          .limit(1)
          .maybeSingle();

      if (profileData == null) {
        print('No manager found');
        setState(() => _isLoading = false);
        return;
      }

      final managerId = profileData['id'] as String;
      print('Loading data for manager: ' + managerId);

      final compoundsData = await Supabase.instance.client
          .from('manager_assignments')
          .select('compounds:compound_id(id, name, location)')
          .eq('manager_id', managerId)
          .eq('is_active', true);

      setState(() {
        _assignedCompounds = List<Map<String, dynamic>>.from(compoundsData);
        _isLoading = false;
      });
    } catch (e) {
      print('Error: ' + e.toString());
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy800,
      appBar: AppBar(
        title: const Text('لوحة تحكم المدير', style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'المجمعات الموكلة إليك',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.gold, fontFamily: 'Tajawal'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_assignedCompounds.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          children: [
                            Icon(Icons.business_outlined, size: 64, color: AppColors.textMuted),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'لا توجد مجمعات موكلة إليك حالياً.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._assignedCompounds.map((assignment) {
                      final compound = assignment['compounds'] as Map<String, dynamic>?;
                      if (compound == null) return const SizedBox.shrink();
                      return GlassCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.location_city, color: AppColors.gold, size: 28),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    compound['name'] as String,
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Tajawal'),
                                  ),
                                ),
                              ],
                            ),
                            if (compound['location'] != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 16, color: AppColors.textMuted),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    compound['location'] as String,
                                    style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}