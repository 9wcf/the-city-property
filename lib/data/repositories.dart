import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/i18n/app_country.dart';
import '../core/utils/app_utils.dart';
import 'models.dart';

typedef CompoundManager = ({String managerId, String fullName, String phoneNumber});
typedef CompoundManagerAssignment = ({
  String compoundId,
  String managerId,
  String fullName,
  String phoneNumber,
});
typedef CreatedTenant = ({String tenantId, String leaseId});
typedef DocumentUploadResult = ({int uploaded, int failed});

class SupabaseRepository {
  SupabaseRepository(this._client);

  static const String documentsBucket = 'tenant-documents';

  final SupabaseClient _client;

  SupabaseClient get client => _client;

  // --------------------------------------------------------------- profiles

  Future<AppProfile?> profileById(String id) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', id)
        .limit(1)
        .maybeSingle();
    return row == null ? null : AppProfile.fromMap(row);
  }

  Future<AppProfile?> findProfileByPhone(String phone) async {
    final local = normalizeLocalPhone(phone);
    var row = await _client
        .from('profiles')
        .select()
        .eq('phone_number', local)
        .limit(1)
        .maybeSingle();
    row ??= await _client
        .from('profiles')
        .select()
        .eq('phone_number', toE164Iraq(local))
        .limit(1)
        .maybeSingle();
    return row == null ? null : AppProfile.fromMap(row);
  }

  Future<AppProfile?> resolveProfile(User user) async {
    final byId = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .limit(1)
        .maybeSingle();
    if (byId != null) return AppProfile.fromMap(byId);

    final metaPhone = user.userMetadata?['phone']?.toString();
    final rawPhone = (user.phone?.isNotEmpty ?? false) ? user.phone : metaPhone;
    if (rawPhone == null || rawPhone.trim().isEmpty) return null;

    final local = normalizeLocalPhone(rawPhone);
    var byPhone = await _client
        .from('profiles')
        .select()
        .eq('phone_number', local)
        .limit(1)
        .maybeSingle();
    byPhone ??= await _client
        .from('profiles')
        .select()
        .eq('phone_number', toE164Iraq(local))
        .limit(1)
        .maybeSingle();
    return byPhone == null ? null : AppProfile.fromMap(byPhone);
  }

  Future<AppProfile> createProfile({
    required String id,
    required String fullName,
    required String phone,
    required UserRole role,
  }) async {
    final local = normalizeLocalPhone(phone);
    final row = await _client
        .from('profiles')
        .insert({
          'id': id,
          'full_name': fullName.trim(),
          'phone_number': local,
          'role': role.dbValue,
          'is_active': true,
        })
        .select()
        .single();
    return AppProfile.fromMap(row);
  }

  Future<AppProfile> ensureProfile(String fullName) async {
    final row = await _client.rpc('ensure_profile', params: {
      'p_full_name': fullName.trim(),
    });
    return AppProfile.fromMap(Map<String, dynamic>.from(row as Map));
  }

  Future<void> claimRole(UserRole role, String inviteCode) async {
    if (role == UserRole.tenant) return;
    await _client.rpc('claim_role', params: {
      'p_role': role.dbValue,
      'p_invite_code': inviteCode.trim(),
    });
  }

  Future<AppProfile> updateProfile({
    required String id,
    String? fullName,
    String? notes,
    String? email,
  }) async {
    final row = await _client
        .from('profiles')
        .update({
          if (fullName != null) 'full_name': fullName.trim(),
          if (notes != null) 'notes': notes.trim(),
          if (email != null) 'email': email.trim(),
        })
        .eq('id', id)
        .select()
        .single();
    return AppProfile.fromMap(row);
  }

  Future<AppProfile?> managerForCompound(String compoundId) async {
    final row = await _client
        .from('manager_assignments')
        .select(
            'profiles:manager_id(id,full_name,phone_number,email,avatar_url,notes,role,is_active)')
        .eq('compound_id', compoundId)
        .eq('is_active', true)
        .limit(1)
        .maybeSingle();
    final profile = row?['profiles'];
    if (profile is! Map) return null;
    return AppProfile.fromMap(Map<String, dynamic>.from(profile));
  }

  /// Manager directly responsible for the apartment, falling back to the
  /// compound manager. Tenants only talk to this person.
  Future<AppProfile?> managerForApartment(
    String apartmentId, {
    String? compoundId,
  }) async {
    try {
      final row = await _client
          .from('apartment_managers')
          .select(
              'profiles:manager_id(id,full_name,phone_number,email,avatar_url,notes,role,is_active)')
          .eq('apartment_id', apartmentId)
          .eq('is_active', true)
          .limit(1)
          .maybeSingle();
      final profile = row?['profiles'];
      if (profile is Map) {
        return AppProfile.fromMap(Map<String, dynamic>.from(profile));
      }
    } on PostgrestException {
      // Privacy rules may hide apartment-level assignments from this user.
    }
    if (compoundId == null) return null;
    return managerForCompound(compoundId);
  }

  Future<List<CompoundManager>> managersForCompound(String compoundId) async {
    final rows = await _client
        .from('manager_assignments')
        .select('manager_id, profiles:manager_id(full_name, phone_number)')
        .eq('compound_id', compoundId)
        .eq('is_active', true);
    return rows.map((row) {
      final profile = row['profiles'];
      final map =
          profile is Map ? Map<String, dynamic>.from(profile) : const <String, dynamic>{};
      final name = map['full_name']?.toString().trim() ?? '';
      return (
        managerId: row['manager_id'].toString(),
        fullName: name.isEmpty ? 'مدير' : name,
        phoneNumber: map['phone_number']?.toString() ?? '',
      );
    }).toList();
  }

  Future<CompoundManager> assignManager({
    required String compoundId,
    required String phone,
  }) async {
    final result = await _client.rpc('assign_manager_to_compound', params: {
      'p_compound_id': compoundId,
      'p_phone': phone.trim(),
    });
    final map =
        result is Map ? Map<String, dynamic>.from(result) : const <String, dynamic>{};
    return (
      managerId: map['manager_id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? 'مدير',
      phoneNumber: map['phone_number']?.toString() ?? '',
    );
  }

  Future<void> removeManager({
    required String compoundId,
    required String managerId,
  }) async {
    await _client.rpc('remove_manager_assignment', params: {
      'p_compound_id': compoundId,
      'p_manager_id': managerId,
    });
  }

  // --------------------------------------------------------- owner dashboard

  Future<List<MemberRow>> ownerMembers() async {
    final rows = await _client.rpc('owner_members');
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => MemberRow.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> setMemberActive({
    required String memberId,
    required bool active,
  }) async {
    await _client.rpc('set_member_active', params: {
      'p_user_id': memberId,
      'p_active': active,
    });
  }

  Future<MemberRow> createManager({
    required String fullName,
    required String phone,
    required String password,
    AppCountry country = AppCountry.iq,
  }) async {
    final result = await _client.rpc('owner_create_manager', params: {
      'p_full_name': fullName.trim(),
      'p_phone': phone.trim(),
      'p_password': password,
      'p_country': country.code,
    });
    final map =
        result is Map ? Map<String, dynamic>.from(result) : const <String, dynamic>{};
    return MemberRow(
      id: map['manager_id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? fullName.trim(),
      phoneNumber: map['phone_number']?.toString() ?? phone.trim(),
      role: UserRole.manager,
      isActive: true,
      scope: 'بدون تعيين',
    );
  }

  Future<void> resetMemberPassword({
    required String memberId,
    required String password,
  }) async {
    await _client.rpc('owner_reset_password', params: {
      'p_user_id': memberId,
      'p_password': password,
    });
  }

  Future<void> deleteArchivedTenant(String tenantId) async {
    final docs = await _client
        .from('lease_documents')
        .select('storage_path')
        .eq('tenant_id', tenantId);
    final paths = docs
        .map((row) => row['storage_path']?.toString())
        .whereType<String>()
        .where((path) => path.trim().isNotEmpty)
        .toList();
    await _client.rpc('owner_delete_archived_tenant', params: {
      'p_tenant_id': tenantId,
    });
    if (paths.isNotEmpty) {
      try {
        await _client.storage.from(documentsBucket).remove(paths);
      } catch (_) {
        // السجل حُذف نهائياً بالفعل؛ فشل تنظيف الملفات لا يغيّر النتيجة.
      }
    }
  }

  Future<List<CompoundManagerAssignment>> compoundManagerAssignments() async {
    final rows = await _client
        .from('manager_assignments')
        .select('compound_id, manager_id, profiles:manager_id(full_name, phone_number)')
        .eq('is_active', true);
    return rows.map((row) {
      final profile = row['profiles'];
      final map =
          profile is Map ? Map<String, dynamic>.from(profile) : const <String, dynamic>{};
      return (
        compoundId: row['compound_id'].toString(),
        managerId: row['manager_id'].toString(),
        fullName: map['full_name']?.toString().trim().isNotEmpty == true
            ? map['full_name'].toString()
            : 'مدير',
        phoneNumber: map['phone_number']?.toString() ?? '',
      );
    }).toList();
  }

  Future<List<ApartmentManagerAssignment>> apartmentManagers() async {
    final rows = await _client
        .from('apartment_managers')
        .select(
            'apartment_id, manager_id, profiles:manager_id(full_name, phone_number), '
            'apartments(unit_number, floors(floor_number, buildings(name, compound_id, compounds(id, name, country))))')
        .eq('is_active', true);
    return rows
        .map((row) =>
            ApartmentManagerAssignment.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<CompoundManager> assignApartmentManager({
    required String apartmentId,
    required String phone,
  }) async {
    final result = await _client.rpc('assign_apartment_manager', params: {
      'p_apartment_id': apartmentId,
      'p_phone': phone.trim(),
    });
    final map =
        result is Map ? Map<String, dynamic>.from(result) : const <String, dynamic>{};
    return (
      managerId: map['manager_id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? 'مدير',
      phoneNumber: map['phone_number']?.toString() ?? '',
    );
  }

  Future<void> removeApartmentManager({
    required String apartmentId,
    required String managerId,
  }) async {
    await _client.rpc('remove_apartment_manager', params: {
      'p_apartment_id': apartmentId,
      'p_manager_id': managerId,
    });
  }

  Future<List<Invoice>> invoices() async {
    final rows = await _client
        .from('invoices')
        .select(
            '*, profiles:tenant_id(full_name), apartments(unit_number, floors(floor_number, buildings(name, compounds(name, country))))')
        .order('invoice_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(500);
    return rows
        .map((row) => Invoice.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<int> generateInvoices({String? compoundId, DateTime? month}) async {
    final target = month ?? DateTime.now();
    final result = await _client.rpc('generate_monthly_invoices', params: {
      'p_compound_id': compoundId,
      'p_month': isoDate(DateTime(target.year, target.month, 1)),
    });
    return result is int ? result : int.tryParse('$result') ?? 0;
  }

  Future<Map<String, dynamic>> recordInvoicePayment({
    required String invoiceId,
    required double amount,
    required String method,
    DateTime? date,
    String? notes,
  }) async {
    final result = await _client.rpc('record_invoice_payment', params: {
      'p_invoice_id': invoiceId,
      'p_amount': amount,
      'p_method': method,
      'p_date': isoDate(date ?? DateTime.now()),
      'p_notes': notes == null || notes.trim().isEmpty ? null : notes.trim(),
    });
    return result is Map ? Map<String, dynamic>.from(result) : const {};
  }

  Future<List<Expense>> expenses() async {
    final rows = await _client
        .from('expenses')
        .select('*, compounds(name, country), buildings(name)')
        .order('expense_date', ascending: false)
        .limit(500);
    return rows
        .map((row) => Expense.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<Expense> addExpense({
    required String compoundId,
    required String category,
    required String title,
    required double amount,
    required DateTime date,
    String? buildingId,
    String? notes,
  }) async {
    final row = await _client
        .from('expenses')
        .insert({
          'compound_id': compoundId,
          if (buildingId != null && buildingId.isNotEmpty)
            'building_id': buildingId,
          'category': category,
          'title': title.trim(),
          'amount': amount,
          'expense_date': isoDate(date),
          'notes': notes == null || notes.trim().isEmpty ? null : notes.trim(),
          'created_by': _client.auth.currentUser?.id,
        })
        .select('*, compounds(name, country), buildings(name)')
        .single();
    return Expense.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> deleteExpense(String id) async {
    await _client.from('expenses').delete().eq('id', id);
  }

  Future<List<AppNotification>> notifications({int limit = 100}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .map((row) => AppNotification.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<int> unreadNotificationCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;
    final rows = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);
    return rows.length;
  }

  Future<void> markNotificationRead(String id) async {
    await _client.from('notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> markAllNotificationsRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toIso8601String(),
    }).eq('user_id', userId).eq('is_read', false);
  }

  Future<int> broadcast({
    required String compoundId,
    required String audience,
    required String title,
    required String body,
  }) async {
    final result = await _client.rpc('owner_broadcast', params: {
      'p_compound_id': compoundId,
      'p_audience': audience,
      'p_title': title.trim(),
      'p_body': body.trim(),
    });
    return result is int ? result : int.tryParse('$result') ?? 0;
  }

  Future<List<Announcement>> ownerAnnouncements() async {
    final rows = await _client
        .from('announcements')
        .select('*, compounds(name, country)')
        .order('published_at', ascending: false)
        .limit(100);
    return rows
        .map((row) => Announcement.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<AppProfile?> ownerForCompound(String compoundId) async {
    final row = await _client
        .from('compounds')
        .select(
            'profiles:owner_id(id,full_name,phone_number,email,avatar_url,notes,role,is_active)')
        .eq('id', compoundId)
        .limit(1)
        .maybeSingle();
    final profile = row?['profiles'];
    if (profile is! Map) return null;
    return AppProfile.fromMap(Map<String, dynamic>.from(profile));
  }

  // -------------------------------------------------------------- portfolio

  Future<String> createCompound({
    required String name,
    String? location,
    String? description,
    AppCountry country = AppCountry.iq,
  }) async {
    final result = await _client.rpc('owner_create_compound', params: {
      'p_name': name.trim(),
      'p_location': location?.trim(),
      'p_description': description?.trim(),
      'p_country': country.code,
    });
    return result.toString();
  }

  Future<void> updateCompound({
    required String compoundId,
    required String name,
    String? location,
    String? description,
    AppCountry? country,
  }) async {
    await _client.rpc('owner_update_compound', params: {
      'p_compound': compoundId,
      'p_name': name.trim(),
      'p_location': location?.trim(),
      'p_description': description?.trim(),
      if (country != null) 'p_country': country.code,
    });
  }

  Future<String> createBuilding({
    required String compoundId,
    required String name,
    String? address,
    required int floors,
    required int unitsPerFloor,
    required double rent,
    required int rooms,
    double? area,
  }) async {
    final result = await _client.rpc('owner_create_building', params: {
      'p_compound': compoundId,
      'p_name': name.trim(),
      'p_address': address?.trim(),
      'p_floors': floors,
      'p_units_per_floor': unitsPerFloor,
      'p_rent': rent,
      'p_rooms': rooms,
      'p_area': area,
    });
    return result.toString();
  }

  Future<String> createApartment({
    required String buildingId,
    required int floorNumber,
    required String unitNumber,
    required double rent,
    required int rooms,
    double? area,
    String? description,
    String? floorLabel,
  }) async {
    final result = await _client.rpc('owner_create_apartment', params: {
      'p_building': buildingId,
      'p_floor_number': floorNumber,
      'p_unit_number': unitNumber.trim(),
      'p_rent': rent,
      'p_rooms': rooms,
      'p_area': area,
      'p_description': description?.trim(),
      'p_floor_label': floorLabel?.trim(),
    });
    return result.toString();
  }

  Future<void> updateApartment({
    required String apartmentId,
    required double rent,
    String? status,
    int? rooms,
    double? area,
    String? description,
    String? unitNumber,
    int? floorNumber,
    String? floorLabel,
  }) async {
    await _client.rpc('owner_update_apartment', params: {
      'p_apartment': apartmentId,
      'p_rent': rent,
      'p_status': status,
      'p_rooms': rooms,
      'p_area': area,
      'p_description': description?.trim(),
      'p_unit_number': unitNumber?.trim(),
      'p_floor_number': floorNumber,
      'p_floor_label': floorLabel?.trim(),
    });
  }

  Future<void> updateBuilding({
    required String buildingId,
    required String name,
    String? address,
    String? description,
    int? totalFloors,
  }) async {
    await _client.rpc('owner_update_building', params: {
      'p_building': buildingId,
      'p_name': name.trim(),
      'p_address': address?.trim(),
      'p_description': description?.trim(),
      'p_total_floors': totalFloors,
    });
  }

  Future<void> deleteApartment(String apartmentId) async {
    await _client.rpc('owner_delete_apartment', params: {
      'p_apartment': apartmentId,
    });
  }

  Future<void> deleteBuilding(String buildingId) async {
    await _client.rpc('owner_delete_building', params: {
      'p_building': buildingId,
    });
  }

  Future<Portfolio> ownerPortfolio(String ownerId) async {
    final rows = await _client
        .from('compounds')
        .select(
            '*, profiles:owner_id(id,full_name,phone_number,email,avatar_url,notes,role,is_active), buildings(*, floors(*, apartments(*)))')
        .eq('owner_id', ownerId)
        .eq('is_active', true)
        .order('created_at');
    return _parsePortfolio(rows);
  }

  Future<Portfolio> managerPortfolio(String managerId) async {
    final rows = await _client
        .from('manager_assignments')
        .select(
            'compounds(*, profiles:owner_id(id,full_name,phone_number,email,avatar_url,notes,role,is_active), buildings(*, floors(*, apartments(*))))')
        .eq('manager_id', managerId)
        .eq('is_active', true);
    final compounds = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final row in rows) {
      final compound = row['compounds'];
      if (compound is! Map) continue;
      final map = Map<String, dynamic>.from(compound);
      final id = map['id']?.toString();
      if (id != null && seen.add(id)) compounds.add(map);
    }

    // Apartments assigned directly to the manager (apartment-level scope).
    final apartmentRows = await _client
        .from('apartment_managers')
        .select(
            'apartments(id, unit_number, floor_label, rent_amount, status, room_count, area_sqm, description, features, floor_id, '
            'floors(floor_number, buildings(id, name, address, total_floors, compound_id, '
            'compounds(id, name, location, description, country, owner_id, profiles:owner_id(id,full_name,phone_number,email,avatar_url,notes,role,is_active)))))')
        .eq('manager_id', managerId)
        .eq('is_active', true);
    final extra = <String, Map<String, dynamic>>{};
    for (final row in apartmentRows) {
      final apartment = row['apartments'];
      if (apartment is! Map) continue;
      final apartmentMap = Map<String, dynamic>.from(apartment);
      final floor = apartmentMap['floors'] is Map
          ? Map<String, dynamic>.from(apartmentMap['floors'] as Map)
          : null;
      final building = floor?['buildings'] is Map
          ? Map<String, dynamic>.from(floor!['buildings'] as Map)
          : null;
      final compound = building?['compounds'] is Map
          ? Map<String, dynamic>.from(building!['compounds'] as Map)
          : null;
      if (floor == null || building == null || compound == null) continue;
      final compoundId = compound['id']?.toString() ?? '';
      if (compoundId.isEmpty || seen.contains(compoundId)) continue;

      final entry = extra.putIfAbsent(
        compoundId,
        () => Map<String, dynamic>.from(compound)
          ..['buildings'] = <Map<String, dynamic>>[],
      );
      final buildings = entry['buildings'] as List<Map<String, dynamic>>;
      var buildingEntry =
          buildings.where((b) => b['id'] == building['id']).firstOrNull;
      if (buildingEntry == null) {
        buildingEntry = Map<String, dynamic>.from(building)
          ..['floors'] = <Map<String, dynamic>>[];
        buildings.add(buildingEntry);
      }
      final floors = buildingEntry['floors'] as List<Map<String, dynamic>>;
      var floorEntry =
          floors.where((f) => f['id'] == floor['id']).firstOrNull;
      if (floorEntry == null) {
        floorEntry = Map<String, dynamic>.from(floor)
          ..['apartments'] = <Map<String, dynamic>>[];
        floors.add(floorEntry);
      }
      final apartments = floorEntry['apartments'] as List<Map<String, dynamic>>;
      final clean = Map<String, dynamic>.from(apartmentMap)..remove('floors');
      if (!apartments.any((a) => a['id'] == clean['id'])) {
        apartments.add(clean);
      }
    }
    compounds.addAll(extra.values);

    return _parsePortfolio(compounds);
  }

  Portfolio _parsePortfolio(List<Map<String, dynamic>> rows) {
    final compounds = <Compound>[];
    for (final c in rows) {
      final compoundId = c['id']?.toString() ?? '';
      final compoundName = c['name']?.toString() ?? 'عقار';
      final compoundCountry =
          AppCountry.fromCode(c['country']?.toString());
      final ownerMap = c['profiles'] is Map
          ? Map<String, dynamic>.from(c['profiles'] as Map)
          : null;
      final buildings = <Building>[];
      final buildingsRaw = c['buildings'];
      if (buildingsRaw is List) {
        for (final b in buildingsRaw) {
          if (b is! Map) continue;
          final building = Map<String, dynamic>.from(b);
          final buildingId = building['id']?.toString() ?? '';
          final buildingName = building['name']?.toString() ?? 'عمارة';
          final floors = <Floor>[];
          final floorsRaw = building['floors'];
          if (floorsRaw is List) {
            for (final f in floorsRaw) {
              if (f is! Map) continue;
              final floor = Map<String, dynamic>.from(f);
              final floorId = floor['id']?.toString() ?? '';
              final floorNumber =
                  int.tryParse('${floor['floor_number'] ?? ''}') ?? 0;
              final apartments = <Apartment>[];
              final apartmentsRaw = floor['apartments'];
              if (apartmentsRaw is List) {
                for (final a in apartmentsRaw) {
                  if (a is! Map) continue;
                  apartments.add(Apartment.fromMap(
                    Map<String, dynamic>.from(a),
                    floorNumber: floorNumber,
                    buildingId: buildingId,
                    buildingName: buildingName,
                    compoundName: compoundName,
                    compoundId: compoundId,
                    floorId: floorId,
                    country: compoundCountry,
                  ));
                }
              }
              apartments.sort((a, b) => a.unitNumber.compareTo(b.unitNumber));
              floors.add(Floor(
                id: floorId,
                buildingId: buildingId,
                floorNumber: floorNumber,
                apartments: apartments,
              ));
            }
          }
          floors.sort((a, b) => a.floorNumber.compareTo(b.floorNumber));
          buildings.add(Building(
            id: buildingId,
            compoundId: compoundId,
            name: buildingName,
            address: building['address']?.toString(),
            description: building['description']?.toString(),
            totalFloors: int.tryParse('${building['total_floors'] ?? ''}') ??
                floors.length,
            floors: floors,
            country: compoundCountry,
          ));
        }
      }
      compounds.add(Compound(
        id: compoundId,
        name: compoundName,
        location: c['location']?.toString(),
        description: c['description']?.toString(),
        ownerId: c['owner_id']?.toString() ?? '',
        buildings: buildings,
        owner: ownerMap == null ? null : AppProfile.fromMap(ownerMap),
        country: compoundCountry,
      ));
    }
    return Portfolio(compounds);
  }

  Future<Apartment?> apartmentById(String apartmentId) async {
    final row = await _client
        .from('apartments')
        .select(
            '*, floors(id, floor_number, buildings(id, name, compound_id, compounds(id, name, country)))')
        .eq('id', apartmentId)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    final floor = row['floors'] is Map
        ? Map<String, dynamic>.from(row['floors'] as Map)
        : null;
    final building = floor?['buildings'] is Map
        ? Map<String, dynamic>.from(floor!['buildings'] as Map)
        : null;
    final compound = building?['compounds'] is Map
        ? Map<String, dynamic>.from(building!['compounds'] as Map)
        : null;
    return Apartment.fromMap(
      row,
      floorNumber: int.tryParse('${floor?['floor_number'] ?? ''}'),
      buildingId: building?['id']?.toString(),
      buildingName: building?['name']?.toString(),
      compoundName: compound?['name']?.toString(),
      compoundId:
          compound?['id']?.toString() ?? building?['compound_id']?.toString(),
      floorId: floor?['id']?.toString() ?? row['floor_id']?.toString(),
      country: AppCountry.fromCode(compound?['country']?.toString()),
    );
  }

  Future<Portfolio> allVacantPortfolio() async {
    final rows = await _client
        .from('compounds')
        .select('*, buildings(*, floors(*, apartments(*)))')
        .eq('is_active', true)
        .order('created_at');
    final parsed = _parsePortfolio(rows);
    final filteredCompounds = <Compound>[];
    for (final compound in parsed.compounds) {
      final buildings = <Building>[];
      for (final building in compound.buildings) {
        final floors = <Floor>[];
        for (final floor in building.floors) {
          final vacant = floor.apartments
              .where((a) => a.status == ApartmentStatus.vacant)
              .toList();
          if (vacant.isNotEmpty) {
            floors.add(Floor(
              id: floor.id,
              buildingId: floor.buildingId,
              floorNumber: floor.floorNumber,
              apartments: vacant,
            ));
          }
        }
        if (floors.isNotEmpty) {
          buildings.add(Building(
            id: building.id,
            compoundId: building.compoundId,
            name: building.name,
            address: building.address,
            description: building.description,
            totalFloors: building.totalFloors,
            floors: floors,
          ));
        }
      }
      if (buildings.isNotEmpty) {
        filteredCompounds.add(Compound(
          id: compound.id,
          name: compound.name,
          location: compound.location,
          description: compound.description,
          ownerId: compound.ownerId,
          buildings: buildings,
          owner: compound.owner,
        ));
      }
    }
    return Portfolio(filteredCompounds);
  }

  // ---------------------------------------------------------------- requests

  Future<List<MaintenanceRequest>> requestsForApartments(
      List<String> apartmentIds) async {
    if (apartmentIds.isEmpty) return const [];
    final rows = await _client
        .from('maintenance_requests')
        .select(
            '*, profiles:tenant_id(id,full_name,phone_number), apartments(id,unit_number)')
        .inFilter('apartment_id', apartmentIds)
        .order('created_at', ascending: false);
    return rows
        .map(
            (row) => MaintenanceRequest.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<MaintenanceRequest>> requestsForTenant(String tenantId) async {
    final rows = await _client
        .from('maintenance_requests')
        .select(
            '*, profiles:tenant_id(id,full_name,phone_number), apartments(id,unit_number)')
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false);
    return rows
        .map(
            (row) => MaintenanceRequest.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<MaintenanceRequest>> requestsForApartment(
      String apartmentId) async {
    final rows = await _client
        .from('maintenance_requests')
        .select(
            '*, profiles:tenant_id(id,full_name,phone_number), apartments(id,unit_number)')
        .eq('apartment_id', apartmentId)
        .order('created_at', ascending: false);
    return rows
        .map(
            (row) => MaintenanceRequest.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<AppProfile?> currentTenantForApartment(String apartmentId) async {
    final row = await _client
        .from('tenant_apartments')
        .select(
            'profiles:tenant_id(id,full_name,phone_number,email,avatar_url,notes,role,is_active)')
        .eq('apartment_id', apartmentId)
        .eq('is_current', true)
        .limit(1)
        .maybeSingle();
    final profile = row?['profiles'];
    if (profile is! Map) return null;
    return AppProfile.fromMap(Map<String, dynamic>.from(profile));
  }

  Future<MaintenanceRequest?> requestById(String requestId) async {
    final row = await _client
        .from('maintenance_requests')
        .select(
            '*, profiles:tenant_id(id,full_name,phone_number), apartments(id,unit_number)')
        .eq('id', requestId)
        .limit(1)
        .maybeSingle();
    return row == null
        ? null
        : MaintenanceRequest.fromMap(Map<String, dynamic>.from(row));
  }

  Future<MaintenanceRequest> createRequest({
    required String apartmentId,
    required String tenantId,
    required String category,
    required String title,
    required String description,
    required String priority,
    List<XFile> images = const [],
  }) async {
    final row = await _client
        .from('maintenance_requests')
        .insert({
          'apartment_id': apartmentId,
          'tenant_id': tenantId,
          'category': category,
          'title': title.trim(),
          'description': description.trim(),
          'status': 'submitted',
          'priority': priority,
          'owner_approval_status': 'pending',
        })
        .select('*, apartments(id,unit_number)')
        .single();

    final requestId = row['id'].toString();
    if (images.isNotEmpty) {
      final urls = await _uploadImages(requestId, images);
      if (urls.isNotEmpty) {
        try {
          await _client
              .from('maintenance_requests')
              .update({'image_urls': urls}).eq('id', requestId);
          row['image_urls'] = urls;
        } catch (_) {
          // Storage/column not provisioned yet; the request still succeeds.
        }
      }
    }
    return MaintenanceRequest.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<String>> _uploadImages(
      String requestId, List<XFile> images) async {
    final urls = <String>[];
    for (final image in images.take(4)) {
      try {
        final bytes = await image.readAsBytes();
        final name = image.name;
        final dot = name.lastIndexOf('.');
        final ext = dot == -1 ? 'jpg' : name.substring(dot + 1).toLowerCase();
        final path = '$requestId/${const Uuid().v4()}.$ext';
        await _client.storage.from('maintenance').uploadBinary(
              path,
              bytes,
              fileOptions:
                  FileOptions(contentType: image.mimeType ?? 'image/jpeg'),
            );
        urls.add(_client.storage.from('maintenance').getPublicUrl(path));
      } catch (_) {
        break;
      }
    }
    return urls;
  }

  Future<void> setEstimate({
    required String requestId,
    required double cost,
    String? notes,
  }) =>
      _updateRequest(requestId, {
        'estimated_cost': cost,
        'owner_approval_status': 'pending',
        'approved_at': null,
        'approved_by': null,
        'rejection_reason': null,
        'manager_notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      });

  Future<void> ownerDecision({
    required String requestId,
    required bool approve,
    required String ownerId,
    String? reason,
  }) =>
      _updateRequest(requestId, {
        'owner_approval_status': approve ? 'approved' : 'rejected',
        'status': approve ? 'approved' : 'rejected',
        'approved_at': DateTime.now().toIso8601String(),
        'approved_by': ownerId,
        'rejection_reason': approve ? null : reason,
        'updated_at': DateTime.now().toIso8601String(),
      });

  Future<void> startWork(String requestId) => _updateRequest(requestId, {
        'status': 'in_progress',
        'started_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

  Future<void> completeWork({
    required String requestId,
    double? finalCost,
    String? notes,
  }) =>
      _updateRequest(requestId, {
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
        'final_cost': finalCost,
        'manager_notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      });

  Future<void> cancelRequest(String requestId) => _updateRequest(requestId, {
        'status': 'cancelled',
        'updated_at': DateTime.now().toIso8601String(),
      });

  Future<void> _updateRequest(
      String requestId, Map<String, dynamic> data) async {
    try {
      await _client
          .from('maintenance_requests')
          .update(data)
          .eq('id', requestId);
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('does not exist') || message.contains('column')) {
        final safe = Map<String, dynamic>.from(data)
          ..remove('manager_notes')
          ..remove('rejection_reason')
          ..remove('image_urls');
        await _client
            .from('maintenance_requests')
            .update(safe)
            .eq('id', requestId);
        return;
      }
      rethrow;
    }
  }

  Future<List<MaintenanceMessage>> messagesForRequest(String requestId) async {
    try {
      final rows = await _client
          .from('maintenance_messages')
          .select('*, profiles:sender_id(id,full_name)')
          .eq('request_id', requestId)
          .order('created_at');
      return rows
          .map((row) =>
              MaintenanceMessage.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } on PostgrestException {
      return const [];
    }
  }

  Future<void> sendMessage({
    required String requestId,
    required String senderId,
    required String body,
  }) async {
    await _client.from('maintenance_messages').insert({
      'request_id': requestId,
      'sender_id': senderId,
      'body': body.trim(),
    });
  }

  // ----------------------------------------------------------------- tenants

  Future<List<TenantRecord>> _tenantRecordsFor(
    List<Apartment> apartments, {
    required List<Payment> payments,
  }) async {
    if (apartments.isEmpty) return const [];
    final ids = apartments.map((a) => a.id).toList();
    final links = await _client
        .from('tenant_apartments')
        .select(
            '*, profiles:tenant_id(id,full_name,phone_number,email,avatar_url,notes,role,is_active)')
        .inFilter('apartment_id', ids)
        .eq('is_current', true);
    final leaseRows = await _client
        .from('leases')
        .select()
        .inFilter('apartment_id', ids)
        .eq('status', 'active')
        .order('created_at', ascending: false);

    final leases = leaseRows
        .map((row) => Lease.fromMap(Map<String, dynamic>.from(row)))
        .toList();
    final now = DateTime.now();
    final records = <TenantRecord>[];
    for (final link in links) {
      final profileMap = link['profiles'];
      if (profileMap is! Map) continue;
      final profile = AppProfile.fromMap(Map<String, dynamic>.from(profileMap));
      final apartmentId = link['apartment_id']?.toString();
      final apartment =
          apartments.where((a) => a.id == apartmentId).firstOrNull;
      if (apartment == null) continue;
      final lease = leases
          .where(
              (l) => l.apartmentId == apartmentId && l.tenantId == profile.id)
          .firstOrNull;
      final paid = payments
          .where((p) =>
              p.tenantId == profile.id && isSameMonth(p.paymentDate, now))
          .fold<double>(0, (sum, p) => sum + p.amount);
      records.add(TenantRecord(
        profile: profile,
        apartment: apartment,
        lease: lease,
        paidThisMonth: paid,
      ));
    }
    return records;
  }

  Future<List<ArchivedTenantRecord>> _ownerArchivedTenantsFor(
    List<Apartment> apartments,
  ) async {
    if (apartments.isEmpty) return const [];
    final response = await _client.rpc('owner_archived_tenants');
    final rows = response is List ? response : const [];
    final records = <ArchivedTenantRecord>[];
    for (final raw in rows) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final profileMap = map['profile'];
      if (profileMap is! Map) continue;
      final profile = AppProfile.fromMap(Map<String, dynamic>.from(profileMap));
      final apartment = apartments
          .where((a) => a.id == map['apartment_id']?.toString())
          .firstOrNull;
      if (apartment == null) continue;
      records.add(ArchivedTenantRecord(
        profile: profile,
        apartment: apartment,
        moveOutDate: DateTime.tryParse(map['move_out_date']?.toString() ?? ''),
        paymentsCount:
            int.tryParse(map['payments_count']?.toString() ?? ''),
        paidTotalOverride:
            double.tryParse(map['paid_total']?.toString() ?? ''),
      ));
    }
    return records;
  }

  Future<List<ArchivedTenantRecord>> _archivedTenantRecordsFor(
    List<Apartment> apartments,
  ) async {
    if (apartments.isEmpty) return const [];
    final ids = apartments.map((a) => a.id).toList();
    final links = await _client
        .from('tenant_apartments')
        .select(
            '*, profiles:tenant_id(id,full_name,phone_number,email,avatar_url,notes,role,is_active)')
        .inFilter('apartment_id', ids)
        .eq('is_current', false)
        .not('move_out_date', 'is', null)
        .order('move_out_date', ascending: false);
    if (links.isEmpty) return const [];

    final tenantIds = links
        .map((link) => link['tenant_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    final payments = await paymentsForTenants(tenantIds);
    final leaseRows = await _client
        .from('leases')
        .select()
        .inFilter('apartment_id', ids)
        .order('created_at', ascending: false);
    final leases = leaseRows
        .map((row) => Lease.fromMap(Map<String, dynamic>.from(row)))
        .toList();

    final records = <ArchivedTenantRecord>[];
    for (final link in links) {
      final profileMap = link['profiles'];
      if (profileMap is! Map) continue;
      final profile = AppProfile.fromMap(Map<String, dynamic>.from(profileMap));
      final apartmentId = link['apartment_id']?.toString();
      final apartment =
          apartments.where((a) => a.id == apartmentId).firstOrNull;
      if (apartment == null) continue;
      final lease = leases
          .where(
              (l) => l.apartmentId == apartmentId && l.tenantId == profile.id)
          .firstOrNull;
      records.add(ArchivedTenantRecord(
        profile: profile,
        apartment: apartment,
        lease: lease,
        moveOutDate:
            DateTime.tryParse(link['move_out_date']?.toString() ?? ''),
        payments:
            payments.where((p) => p.tenantId == profile.id).toList(),
      ));
    }
    return records;
  }

  Future<List<Payment>> paymentsForTenants(List<String> tenantIds) async {
    if (tenantIds.isEmpty) return const [];
    final rows = await _client
        .from('payments')
        .select('*, profiles:tenant_id(id,full_name)')
        .inFilter('tenant_id', tenantIds)
        .order('payment_date', ascending: false);
    return rows
        .map((row) => Payment.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<Payment>> paymentsForTenant(String tenantId) async {
    final rows = await _client
        .from('payments')
        .select()
        .eq('tenant_id', tenantId)
        .order('payment_date', ascending: false);
    return rows
        .map((row) => Payment.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<Payment> recordPayment({
    required String tenantId,
    required double amount,
    required String method,
    DateTime? date,
    String? receiptNumber,
    String? notes,
  }) async {
    final row = await _client
        .from('payments')
        .insert({
          'tenant_id': tenantId,
          'created_by': _client.auth.currentUser?.id,
          'amount': amount,
          'payment_date': isoDate(date ?? DateTime.now()),
          'payment_method': method,
          if (receiptNumber != null && receiptNumber.trim().isNotEmpty)
            'receipt_number': receiptNumber.trim(),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        })
        .select()
        .single();
    return Payment.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<Lease>> pendingLeasesForApartments(
      List<String> apartmentIds) async {
    if (apartmentIds.isEmpty) return const [];
    try {
      final rows = await _client
          .from('leases')
          .select(
              '*, profiles:tenant_id(id,full_name,phone_number), apartments(id,unit_number,floor_label,floors(floor_number,buildings(name)))')
          .inFilter('apartment_id', apartmentIds)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return rows
          .map((row) => Lease.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } on PostgrestException catch (error) {
      // Older schemas lack the pending/rejected lease_status values.
      if (!error.message.contains('invalid input value for enum')) rethrow;
      return const [];
    }
  }

  Future<Lease?> activeLeaseForApartment(String apartmentId) async {
    final row = await _client
        .from('leases')
        .select()
        .eq('apartment_id', apartmentId)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : Lease.fromMap(row);
  }

  Future<CreatedTenant> managerAddTenant({
    required String managerId,
    required String fullName,
    required String phone,
    required Apartment apartment,
    required double monthlyRent,
    required DateTime startDate,
    required DateTime endDate,
    double deposit = 0,
    String? notes,
    String? password,
  }) async {
    final raw = await _client.rpc('manager_add_tenant', params: {
      'p_manager_id': managerId,
      'p_full_name': fullName.trim(),
      'p_phone': phone.trim(),
      'p_apartment_id': apartment.id,
      'p_rent': monthlyRent,
      'p_deposit': deposit,
      'p_start_date': isoDate(startDate),
      'p_end_date': isoDate(endDate),
      'p_notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
      if (password != null && password.isNotEmpty) 'p_password': password,
    });
    final data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
    final tenantId = data['tenant_id']?.toString();
    final leaseId = data['lease_id']?.toString();
    if (tenantId == null || leaseId == null || tenantId.isEmpty || leaseId.isEmpty) {
      throw Exception('تم إنشاء المستأجر لكن تعذر استرجاع بيانات العقد');
    }
    return (tenantId: tenantId, leaseId: leaseId);
  }

  Future<DocumentUploadResult> uploadLeaseDocuments({
    required String leaseId,
    required String tenantId,
    required String? apartmentId,
    required String kind,
    required List<XFile> files,
  }) async {
    var uploaded = 0;
    var failed = 0;
    final uploaderId = _client.auth.currentUser?.id;
    for (final file in files) {
      String? path;
      try {
        final bytes = await file.readAsBytes();
        final originalName = file.name.trim().isEmpty ? 'document.jpg' : file.name;
        final dot = originalName.lastIndexOf('.');
        final ext =
            dot == -1 ? 'jpg' : originalName.substring(dot + 1).toLowerCase();
        path = '$leaseId/$kind/${const Uuid().v4()}.$ext';
        final contentType = _contentType(originalName, file.mimeType);
        await _client.storage.from(documentsBucket).uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: contentType, upsert: false),
            );
        await _client.from('lease_documents').insert({
          'lease_id': leaseId,
          'tenant_id': tenantId,
          'apartment_id': apartmentId,
          'kind': kind,
          'storage_path': path,
          'file_name': originalName,
          'mime_type': contentType,
          'size_bytes': bytes.length,
          'uploaded_by': uploaderId,
        });
        uploaded += 1;
      } catch (_) {
        failed += 1;
        if (path != null) {
          try {
            await _client.storage.from(documentsBucket).remove([path]);
          } catch (_) {}
        }
      }
    }
    return (uploaded: uploaded, failed: failed);
  }

  Future<List<LeaseDocument>> leaseDocuments(String leaseId) async {
    final rows = await _client
        .from('lease_documents')
        .select()
        .eq('lease_id', leaseId)
        .order('created_at');
    final documents = <LeaseDocument>[];
    for (final row in rows) {
      final document = LeaseDocument.fromMap(Map<String, dynamic>.from(row));
      String? signedUrl;
      try {
        signedUrl = await _client.storage
            .from(documentsBucket)
            .createSignedUrl(document.storagePath, 3600);
      } catch (_) {}
      documents.add(document.withSignedUrl(signedUrl));
    }
    return documents;
  }

  Future<void> deleteLeaseDocument(LeaseDocument document) async {
    await _client.from('lease_documents').delete().eq('id', document.id);
    try {
      await _client.storage
          .from(documentsBucket)
          .remove([document.storagePath]);
    } catch (_) {}
  }

  String _contentType(String fileName, String? declared) {
    final lower = declared?.trim().toLowerCase() ?? '';
    if (lower == 'image/jpg') return 'image/jpeg';
    if (lower == 'image/x-png') return 'image/png';
    if (lower == 'image/heif') return 'image/heic';
    if (lower.startsWith('image/') || lower == 'application/pdf') {
      return lower;
    }
    final name = fileName.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.heic') || name.endsWith('.heif')) return 'image/heic';
    if (name.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }

  Future<void> requestTenantLink({
    required AppProfile tenant,
    required Apartment apartment,
    required double monthlyRent,
    required DateTime startDate,
    required DateTime endDate,
    double deposit = 0,
    String? notes,
  }) async {
    final existing = await _client
        .from('leases')
        .select('id')
        .eq('tenant_id', tenant.id)
        .eq('status', 'pending')
        .limit(1)
        .maybeSingle();
    if (existing != null) {
      throw Exception('لديك طلب ربط شقة قيد المراجعة بالفعل');
    }
    await _client.from('leases').insert({
      'apartment_id': apartment.id,
      'tenant_id': tenant.id,
      'start_date': isoDate(startDate),
      'end_date': isoDate(endDate),
      'monthly_rent': monthlyRent,
      'deposit_amount': deposit,
      'status': 'pending',
      'notes': notes,
    });
    // A previous rejected request leaves a non-current link behind; the
    // unique (tenant_id, apartment_id) pair forces a clean re-insert.
    await _client
        .from('tenant_apartments')
        .delete()
        .eq('tenant_id', tenant.id)
        .eq('apartment_id', apartment.id)
        .eq('is_current', false);
    await _client.from('tenant_apartments').insert({
      'tenant_id': tenant.id,
      'apartment_id': apartment.id,
      'move_in_date': isoDate(startDate),
      'is_current': false,
    });
  }

  Future<void> approveLease(Lease lease) async {
    await _client
        .from('leases')
        .update({'status': 'active'}).eq('id', lease.id);
    await _client
        .from('tenant_apartments')
        .update({'is_current': true})
        .eq('tenant_id', lease.tenantId)
        .eq('apartment_id', lease.apartmentId);
    await _client
        .from('apartments')
        .update({'status': 'occupied'}).eq('id', lease.apartmentId);
  }

  Future<void> rejectLease(Lease lease) async {
    await _client
        .from('leases')
        .update({'status': 'rejected'}).eq('id', lease.id);
    await _client
        .from('tenant_apartments')
        .update({'is_current': false})
        .eq('tenant_id', lease.tenantId)
        .eq('apartment_id', lease.apartmentId);
  }

  Future<Map<String, dynamic>> vacateTenant({
    required String tenantId,
    required String apartmentId,
    DateTime? moveOutDate,
    String? notes,
  }) async {
    final result = await _client.rpc('vacate_tenant', params: {
      'p_tenant_id': tenantId,
      'p_apartment_id': apartmentId,
      'p_move_out_date': isoDate(moveOutDate ?? DateTime.now()),
      'p_notes': notes == null || notes.trim().isEmpty ? null : notes.trim(),
    });
    return result is Map ? Map<String, dynamic>.from(result) : const {};
  }

  // ---------------------------------------------------------------- snapshots

  Future<OwnerSnapshot> ownerSnapshot(AppProfile owner) async {
    final portfolio = await ownerPortfolio(owner.id);
    final apartmentIds = portfolio.apartmentIds;
    final requests = await requestsForApartments(apartmentIds);
    final links = apartmentIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _client
            .from('tenant_apartments')
            .select('tenant_id')
            .inFilter('apartment_id', apartmentIds)
            .eq('is_current', true);
    final tenantIds =
        links.map((e) => e['tenant_id'].toString()).toSet().toList();
    final payments = await paymentsForTenants(tenantIds);
    final tenants =
        await _tenantRecordsFor(portfolio.apartments, payments: payments);
    final archivedTenants =
        await _ownerArchivedTenantsFor(portfolio.apartments);
    return OwnerSnapshot(
      owner: owner,
      portfolio: portfolio,
      requests: requests,
      payments: payments,
      tenants: tenants,
      archivedTenants: archivedTenants,
    );
  }

  Future<ManagerSnapshot> managerSnapshot(AppProfile manager) async {
    final portfolio = await managerPortfolio(manager.id);
    final apartmentIds = portfolio.apartmentIds;
    final requests = await requestsForApartments(apartmentIds);
    final pendingLeases = await pendingLeasesForApartments(apartmentIds);
    final links = apartmentIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _client
            .from('tenant_apartments')
            .select('tenant_id')
            .inFilter('apartment_id', apartmentIds)
            .eq('is_current', true);
    final tenantIds =
        links.map((e) => e['tenant_id'].toString()).toSet().toList();
    final payments = await paymentsForTenants(tenantIds);
    final tenants =
        await _tenantRecordsFor(portfolio.apartments, payments: payments);
    final archivedTenants =
        await _archivedTenantRecordsFor(portfolio.apartments);
    return ManagerSnapshot(
      manager: manager,
      portfolio: portfolio,
      requests: requests,
      tenants: tenants,
      archivedTenants: archivedTenants,
      pendingLeases: pendingLeases,
      payments: payments,
    );
  }

  Future<TenantSnapshot> tenantSnapshot(AppProfile tenant) async {
    final link = await _client
        .from('tenant_apartments')
        .select('apartment_id')
        .eq('tenant_id', tenant.id)
        .eq('is_current', true)
        .limit(1)
        .maybeSingle();

    Apartment? apartment;
    Lease? lease;
    if (link != null) {
      final apartmentId = link['apartment_id'].toString();
      apartment = await apartmentById(apartmentId);
      lease = await activeLeaseForApartment(apartmentId);
    } else {
      Map<String, dynamic>? pending;
      try {
        pending = await _client
            .from('leases')
            .select()
            .eq('tenant_id', tenant.id)
            .inFilter('status', ['pending', 'active'])
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
      } on PostgrestException catch (error) {
        // Older schemas lack the pending/rejected lease_status values.
        if (!error.message.contains('invalid input value for enum')) rethrow;
      }
      if (pending != null) {
        lease = Lease.fromMap(Map<String, dynamic>.from(pending));
        apartment = await apartmentById(lease.apartmentId);
      }
    }

    final payments = await paymentsForTenant(tenant.id);
    final requests = await requestsForTenant(tenant.id);
    AppProfile? manager;
    if (apartment != null) {
      manager = await managerForApartment(
        apartment.id,
        compoundId: apartment.compoundId,
      );
    }

    return TenantSnapshot(
      tenant: tenant,
      apartment: apartment,
      lease: lease,
      manager: manager,
      payments: payments,
      requests: requests,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
