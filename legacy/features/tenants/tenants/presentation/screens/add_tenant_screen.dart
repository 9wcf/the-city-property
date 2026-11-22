import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:the_city_property/core/theme/app_colors.dart';
import 'package:the_city_property/core/theme/app_spacing.dart';
import 'package:the_city_property/core/widgets/glass_card.dart';

class AddTenantScreen extends ConsumerStatefulWidget {
  const AddTenantScreen({super.key});

  @override
  ConsumerState<AddTenantScreen> createState() => _AddTenantScreenState();
}

class _AddTenantScreenState extends ConsumerState<AddTenantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _rentController = TextEditingController();

  String? _selectedCompound;
  String? _selectedBuilding;
  String? _selectedFloor;
  String? _selectedApartment;

  List<Map<String, dynamic>> _compounds = [];
  List<Map<String, dynamic>> _buildings = [];
  List<Map<String, dynamic>> _floors = [];
  List<Map<String, dynamic>> _apartments = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCompounds();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _rentController.dispose();
    super.dispose();
  }

  Future<void> _loadCompounds() async {
    try {
      final profileData = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('role', 'owner')
          .limit(1)
          .maybeSingle();

      if (profileData == null) return;

      final ownerId = profileData['id'] as String;
      final data = await Supabase.instance.client
          .from('compounds')
          .select()
          .eq('owner_id', ownerId);

      setState(() {
        _compounds = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      print('Error loading compounds: ' + e.toString());
    }
  }

  Future<void> _loadBuildings(String compoundId) async {
    try {
      final data = await Supabase.instance.client
          .from('buildings')
          .select()
          .eq('compound_id', compoundId);

      setState(() {
        _buildings = List<Map<String, dynamic>>.from(data);
        _selectedBuilding = null;
        _selectedFloor = null;
        _selectedApartment = null;
      });
    } catch (e) {
      print('Error loading buildings: ' + e.toString());
    }
  }

  Future<void> _loadFloors(String buildingId) async {
    try {
      final data = await Supabase.instance.client
          .from('floors')
          .select()
          .eq('building_id', buildingId)
          .order('floor_number');

      setState(() {
        _floors = List<Map<String, dynamic>>.from(data);
        _selectedFloor = null;
        _selectedApartment = null;
      });
    } catch (e) {
      print('Error loading floors: ' + e.toString());
    }
  }

  Future<void> _loadApartments(String floorId) async {
    try {
      final data = await Supabase.instance.client
          .from('apartments')
          .select()
          .eq('floor_id', floorId)
          .eq('status', 'vacant');

      setState(() {
        _apartments = List<Map<String, dynamic>>.from(data);
        _selectedApartment = null;
      });
    } catch (e) {
      print('Error loading apartments: ' + e.toString());
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedApartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار الشقة'),
          backgroundColor: AppColors.vacant,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final phone = _phoneController.text.trim();
      final name = _nameController.text.trim();
      final rent = double.tryParse(_rentController.text) ?? 500000;

      // إنشاء بريد إلكتروني فريد لتجنب التعارض
      final uniqueEmail = 'tenant_' + DateTime.now().millisecondsSinceEpoch.toString() + '@thecity.local';

      // 1. إنشاء حساب المستخدم في Auth (الطريقة الصحيحة والمعتمدة)
      final authResponse = await Supabase.instance.client.auth.signUp(
        email: uniqueEmail,
        password: 'TempPass123!',
        data: {
          'phone': phone,
          'full_name': name,
          'role': 'tenant',
        },
      );

      if (authResponse.user == null) {
        throw Exception('فشل في إنشاء الحساب');
      }

      final userId = authResponse.user!.id;
      print('Created user: ' + userId);

      // 2. إنشاء عقد الإيجار
      final startDate = DateTime.now();
      final endDate = startDate.add(const Duration(days: 365));

      await Supabase.instance.client.from('leases').insert({
        'apartment_id': _selectedApartment,
        'tenant_id': userId,
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
        'monthly_rent': rent,
        'status': 'active',
      });

      print('Created lease for apartment: ' + _selectedApartment!);

      // 3. تحديث حالة الشقة إلى مؤجرة
      await Supabase.instance.client
          .from('apartments')
          .update({'status': 'occupied'})
          .eq('id', _selectedApartment!);

      print('Updated apartment status to occupied');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة المستأجر وتحديث حالة الشقة بنجاح'),
            backgroundColor: AppColors.occupied,
          ),
        );
        context.pop();
      }
    } catch (e) {
      print('Error: ' + e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: ' + e.toString()),
            backgroundColor: AppColors.vacant,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy800,
      appBar: AppBar(
        title: const Text('إضافة مستأجر جديد', style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'معلومات المستأجر',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.gold, fontFamily: 'Tajawal'),
              ),
              const SizedBox(height: AppSpacing.md),

              GlassCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Tajawal'),
                      decoration: const InputDecoration(
                        labelText: 'الاسم الكامل',
                        prefixIcon: Icon(Icons.person, color: AppColors.gold),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'يرجى إدخال الاسم';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Tajawal'),
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                        prefixIcon: Icon(Icons.phone, color: AppColors.gold),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'يرجى إدخال رقم الهاتف';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _rentController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Tajawal'),
                      decoration: const InputDecoration(
                        labelText: 'الإيجار الشهري (دينار)',
                        hintText: '500000',
                        prefixIcon: Icon(Icons.attach_money, color: AppColors.gold),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'يرجى إدخال الإيجار';
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
              const Text(
                'موقع الشقة',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.gold, fontFamily: 'Tajawal'),
              ),
              const SizedBox(height: AppSpacing.md),

              GlassCard(
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedCompound,
                      items: _compounds.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] as String))).toList(),
                      onChanged: (value) { setState(() => _selectedCompound = value); if (value != null) _loadBuildings(value); },
                      decoration: const InputDecoration(labelText: 'المجمع', prefixIcon: Icon(Icons.location_city, color: AppColors.gold)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      value: _selectedBuilding,
                      items: _buildings.map((b) => DropdownMenuItem(value: b['id'] as String, child: Text(b['name'] as String))).toList(),
                      onChanged: (value) { setState(() => _selectedBuilding = value); if (value != null) _loadFloors(value); },
                      decoration: const InputDecoration(labelText: 'العمارة', prefixIcon: Icon(Icons.apartment, color: AppColors.gold)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      value: _selectedFloor,
                      items: _floors.map((f) => DropdownMenuItem(value: f['id'] as String, child: Text('طابق ' + f['floor_number'].toString()))).toList(),
                      onChanged: (value) { setState(() => _selectedFloor = value); if (value != null) _loadApartments(value); },
                      decoration: const InputDecoration(labelText: 'الطابق', prefixIcon: Icon(Icons.layers, color: AppColors.gold)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      value: _selectedApartment,
                      items: _apartments.map((a) => DropdownMenuItem(value: a['id'] as String, child: Text('شقة ' + a['unit_number'].toString()))).toList(),
                      onChanged: (value) => setState(() => _selectedApartment = value),
                      decoration: const InputDecoration(labelText: 'الشقة', prefixIcon: Icon(Icons.door_front_door, color: AppColors.gold)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: AppColors.navy900)
                      : const Text('إضافة المستأجر', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Tajawal')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}