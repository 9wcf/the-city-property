import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/i18n/app_country.dart';
import '../core/theme/app_colors.dart';

double _d(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

int _i(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

String? _s(dynamic v) {
  if (v == null) return null;
  final text = v.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime? _dt(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

bool _b(dynamic v, [bool fallback = false]) {
  if (v == null) return fallback;
  if (v is bool) return v;
  return v.toString().toLowerCase() == 'true';
}

List<String> _strings(dynamic v) {
  if (v == null) return const [];
  if (v is List) return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  if (v is String) {
    final trimmed = v.trim();
    if (trimmed.startsWith('[')) {
      return trimmed.replaceAll(RegExp(r'[\[\]"]'), '').split(',').where((e) => e.trim().isNotEmpty).toList();
    }
    return trimmed.isEmpty ? const [] : [trimmed];
  }
  return const [];
}

enum UserRole { owner, manager, tenant }

UserRole roleFrom(String? value) {
  switch (value) {
    case 'owner':
      return UserRole.owner;
    case 'manager':
      return UserRole.manager;
    default:
      return UserRole.tenant;
  }
}

extension UserRoleX on UserRole {
  String get dbValue => name;
  String get label => switch (this) {
        UserRole.owner => 'مالك',
        UserRole.manager => 'مدير عقارات',
        UserRole.tenant => 'مستأجر',
      };
  IconData get icon => switch (this) {
        UserRole.owner => Icons.workspace_premium_rounded,
        UserRole.manager => Icons.support_agent_rounded,
        UserRole.tenant => Icons.person_rounded,
      };
}

enum ApartmentStatus { occupied, vacant, maintenance, reserved }

ApartmentStatus apartmentStatusFrom(String? value) {
  switch (value) {
    case 'occupied':
      return ApartmentStatus.occupied;
    case 'maintenance':
      return ApartmentStatus.maintenance;
    case 'reserved':
      return ApartmentStatus.reserved;
    default:
      return ApartmentStatus.vacant;
  }
}

extension ApartmentStatusX on ApartmentStatus {
  String get dbValue => name;
  String get label => switch (this) {
        ApartmentStatus.occupied => 'مؤجرة',
        ApartmentStatus.vacant => 'فارغة',
        ApartmentStatus.maintenance => 'صيانة',
        ApartmentStatus.reserved => 'محجوزة',
      };
  IconData get icon => switch (this) {
        ApartmentStatus.occupied => Icons.check_circle_rounded,
        ApartmentStatus.vacant => Icons.home_outlined,
        ApartmentStatus.maintenance => Icons.build_rounded,
        ApartmentStatus.reserved => Icons.lock_clock_rounded,
      };
}

class AppProfile {
  final String id;
  final String? fullName;
  final String phoneNumber;
  final String? email;
  final String? avatarUrl;
  final String? notes;
  final UserRole role;
  final bool isActive;
  final AppCountry country;

  const AppProfile({
    required this.id,
    required this.phoneNumber,
    required this.role,
    this.fullName,
    this.email,
    this.avatarUrl,
    this.notes,
    this.isActive = true,
    this.country = AppCountry.iq,
  });

  factory AppProfile.fromMap(Map<String, dynamic> map) => AppProfile(
        id: map['id'].toString(),
        fullName: _s(map['full_name']),
        phoneNumber: _s(map['phone_number']) ?? '',
        email: _s(map['email']),
        avatarUrl: _s(map['avatar_url']),
        notes: _s(map['notes']),
        role: roleFrom(_s(map['role'])),
        isActive: _b(map['is_active'], true),
        country: AppCountry.fromCode(_s(map['country'])),
      );

  String get displayName {
    final name = fullName?.trim() ?? '';
    return name.isEmpty ? phoneNumber : name;
  }

  String get initials {
    final parts = displayName.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '؟';
    if (parts.length == 1) return parts.first.substring(0, 1);
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}';
  }
}

class Floor {
  final String id;
  final String buildingId;
  final int floorNumber;
  final List<Apartment> apartments;

  const Floor({
    required this.id,
    required this.buildingId,
    required this.floorNumber,
    this.apartments = const [],
  });
}

class Building {
  final String id;
  final String compoundId;
  final String name;
  final String? address;
  final String? description;
  final int totalFloors;
  final List<Floor> floors;
  final AppCountry country;

  const Building({
    required this.id,
    required this.compoundId,
    required this.name,
    this.address,
    this.description,
    this.totalFloors = 0,
    this.floors = const [],
    this.country = AppCountry.iq,
  });

  List<Apartment> get apartments => floors.expand((f) => f.apartments).toList();
}

class Compound {
  final String id;
  final String name;
  final String? location;
  final String? description;
  final String ownerId;
  final List<Building> buildings;
  final AppProfile? owner;
  final AppCountry country;

  const Compound({
    required this.id,
    required this.name,
    required this.ownerId,
    this.location,
    this.description,
    this.buildings = const [],
    this.owner,
    this.country = AppCountry.iq,
  });

  List<Apartment> get apartments => buildings.expand((b) => b.apartments).toList();
}

/// Turns a stored unit value into a readable apartment name.
/// Free-text values such as «شقة رقم واحد» are shown as written, while a bare
/// number like «12» becomes «شقة 12».
String apartmentDisplayName(String? unitNumber) {
  final raw = (unitNumber ?? '').trim();
  if (raw.isEmpty || raw == '—') return 'شقة';
  final first = raw.split(RegExp(r'\s+')).first;
  const prefixes = {
    'شقة',
    'شقه',
    'الشقة',
    'الشقه',
    'وحدة',
    'وحده',
    'الوحدة',
    'الوحده',
  };
  return prefixes.contains(first) ? raw : 'شقة $raw';
}

class Apartment {
  final String id;
  final String floorId;
  final String? buildingId;
  final String unitNumber;
  final int roomCount;
  final double? areaSqm;
  final double rentAmount;
  final ApartmentStatus status;
  final String? description;
  final List<String> features;
  final int? floorNumber;
  final String? floorLabelText;
  final String? buildingName;
  final String? compoundName;
  final String? compoundId;
  final AppCountry country;

  const Apartment({
    required this.id,
    required this.floorId,
    required this.unitNumber,
    required this.rentAmount,
    required this.status,
    this.buildingId,
    this.roomCount = 0,
    this.areaSqm,
    this.description,
    this.features = const [],
    this.floorNumber,
    this.floorLabelText,
    this.buildingName,
    this.compoundName,
    this.compoundId,
    this.country = AppCountry.iq,
  });

  factory Apartment.fromMap(
    Map<String, dynamic> map, {
    int? floorNumber,
    String? buildingId,
    String? buildingName,
    String? compoundName,
    String? compoundId,
    String? floorId,
    AppCountry? country,
  }) =>
      Apartment(
        id: map['id'].toString(),
        floorId: floorId ?? _s(map['floor_id']) ?? '',
        buildingId: buildingId,
        unitNumber: _s(map['unit_number']) ?? '—',
        roomCount: _i(map['room_count']),
        areaSqm: map['area_sqm'] == null ? null : _d(map['area_sqm']),
        rentAmount: _d(map['rent_amount']),
        status: apartmentStatusFrom(_s(map['status'])),
        description: _s(map['description']),
        features: _strings(map['features']),
        floorNumber: floorNumber,
        floorLabelText: _s(map['floor_label']),
        buildingName: buildingName,
        compoundName: compoundName,
        compoundId: compoundId,
        country: country ?? AppCountry.iq,
      );

  String get displayName => apartmentDisplayName(unitNumber);

  String get label {
    final building = buildingName ?? '';
    return building.isEmpty ? displayName : '$displayName · $building';
  }

  String get floorLabel {
    final custom = floorLabelText?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    if (floorNumber == null) return '';
    return floorNumber == 0 ? 'الطابق الأرضي' : 'الطابق $floorNumber';
  }
}

class Lease {
  final String id;
  final String apartmentId;
  final String tenantId;
  final DateTime startDate;
  final DateTime endDate;
  final double monthlyRent;
  final double depositAmount;
  final String status;
  final String? notes;
  final String? terms;
  final DateTime? createdAt;
  final String? tenantName;
  final String? tenantPhone;
  final String? apartmentLabel;

  const Lease({
    required this.id,
    required this.apartmentId,
    required this.tenantId,
    required this.startDate,
    required this.endDate,
    required this.monthlyRent,
    required this.status,
    this.depositAmount = 0,
    this.notes,
    this.terms,
    this.createdAt,
    this.tenantName,
    this.tenantPhone,
    this.apartmentLabel,
  });

  factory Lease.fromMap(Map<String, dynamic> map) {
    final tenant = map['profiles'] is Map ? Map<String, dynamic>.from(map['profiles'] as Map) : null;
    final apartment = map['apartments'] is Map ? Map<String, dynamic>.from(map['apartments'] as Map) : null;
    String? label;
    if (apartment != null) {
      final floors = apartment['floors'] is Map ? Map<String, dynamic>.from(apartment['floors'] as Map) : null;
      final buildings = floors?['buildings'] is Map ? Map<String, dynamic>.from(floors!['buildings'] as Map) : null;
      label = apartmentDisplayName(_s(apartment['unit_number']));
      if (buildings?['name'] != null) label = '$label · ${buildings!['name']}';
      final floorText = _s(apartment['floor_label']);
      if (floorText != null && floorText.isNotEmpty) {
        label = '$label · $floorText';
      } else if (floors?['floor_number'] != null) {
        label = '$label · طابق ${floors!['floor_number']}';
      }
    }
    return Lease(
      id: map['id'].toString(),
      apartmentId: map['apartment_id'].toString(),
      tenantId: map['tenant_id'].toString(),
      startDate: _dt(map['start_date']) ?? DateTime.now(),
      endDate: _dt(map['end_date']) ?? DateTime.now(),
      monthlyRent: _d(map['monthly_rent']),
      depositAmount: _d(map['deposit_amount']),
      status: _s(map['status']) ?? 'pending',
      notes: _s(map['notes']),
      terms: _s(map['terms']),
      createdAt: _dt(map['created_at']),
      tenantName: tenant == null ? null : _s(tenant['full_name']),
      tenantPhone: tenant == null ? null : _s(tenant['phone_number']),
      apartmentLabel: label,
    );
  }

  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';
}

class Payment {
  final String id;
  final String tenantId;
  final double amount;
  final DateTime paymentDate;
  final String paymentMethod;
  final String? receiptNumber;
  final String? receiptUrl;
  final String? notes;
  final DateTime? createdAt;
  final String? tenantName;

  const Payment({
    required this.id,
    required this.tenantId,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    this.receiptNumber,
    this.receiptUrl,
    this.notes,
    this.createdAt,
    this.tenantName,
  });

  factory Payment.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] is Map ? Map<String, dynamic>.from(map['profiles'] as Map) : null;
    return Payment(
      id: map['id'].toString(),
      tenantId: map['tenant_id'].toString(),
      amount: _d(map['amount']),
      paymentDate: _dt(map['payment_date']) ?? DateTime.now(),
      paymentMethod: _s(map['payment_method']) ?? 'cash',
      receiptNumber: _s(map['receipt_number']),
      receiptUrl: _s(map['receipt_url']),
      notes: _s(map['notes']),
      createdAt: _dt(map['created_at']),
      tenantName: profile == null ? null : _s(profile['full_name']),
    );
  }

  String get methodLabel => switch (paymentMethod) {
        'cash' => 'نقداً',
        'transfer' => 'تحويل بنكي',
        'card' => 'بطاقة',
        'cheque' => 'صك',
        _ => paymentMethod,
      };
}

class MaintenanceRequest {
  final String id;
  final String apartmentId;
  final String tenantId;
  final String category;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String ownerApprovalStatus;
  final double? estimatedCost;
  final double? finalCost;
  final DateTime? approvedAt;
  final String? approvedBy;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String> imageUrls;
  final String? managerNotes;
  final String? rejectionReason;
  final String? tenantName;
  final String? managerName;
  final String? apartmentLabel;

  const MaintenanceRequest({
    required this.id,
    required this.apartmentId,
    required this.tenantId,
    required this.category,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.ownerApprovalStatus,
    this.estimatedCost,
    this.finalCost,
    this.approvedAt,
    this.approvedBy,
    this.startedAt,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
    this.imageUrls = const [],
    this.managerNotes,
    this.rejectionReason,
    this.tenantName,
    this.managerName,
    this.apartmentLabel,
  });

  factory MaintenanceRequest.fromMap(Map<String, dynamic> map) {
    final tenant = map['tenant_profile'] is Map
        ? Map<String, dynamic>.from(map['tenant_profile'] as Map)
        : (map['profiles'] is Map ? Map<String, dynamic>.from(map['profiles'] as Map) : null);
    final apartment = map['apartments'] is Map ? Map<String, dynamic>.from(map['apartments'] as Map) : null;
    return MaintenanceRequest(
      id: map['id'].toString(),
      apartmentId: map['apartment_id'].toString(),
      tenantId: map['tenant_id'].toString(),
      category: _s(map['category']) ?? 'other',
      title: _s(map['title']) ?? '',
      description: _s(map['description']) ?? '',
      status: _s(map['status']) ?? 'submitted',
      priority: _s(map['priority']) ?? 'normal',
      ownerApprovalStatus: _s(map['owner_approval_status']) ?? 'pending',
      estimatedCost: map['estimated_cost'] == null ? null : _d(map['estimated_cost']),
      finalCost: map['final_cost'] == null ? null : _d(map['final_cost']),
      approvedAt: _dt(map['approved_at']),
      approvedBy: _s(map['approved_by']),
      startedAt: _dt(map['started_at']),
      completedAt: _dt(map['completed_at']),
      createdAt: _dt(map['created_at']),
      updatedAt: _dt(map['updated_at']),
      imageUrls: _strings(map['image_urls']),
      managerNotes: _s(map['manager_notes']),
      rejectionReason: _s(map['rejection_reason']),
      tenantName: tenant == null ? null : _s(tenant['full_name']),
      apartmentLabel: apartment == null
          ? null
          : apartmentDisplayName(_s(apartment['unit_number'])),
    );
  }

  bool get needsOwnerApproval =>
      estimatedCost != null && ownerApprovalStatus == 'pending' && status != 'completed';
  bool get isApproved => ownerApprovalStatus == 'approved';
  bool get isRejected => ownerApprovalStatus == 'rejected';
  bool get isOpen => status != 'completed' && status != 'cancelled' && status != 'rejected';
  bool get isCompleted => status == 'completed';
  bool get isInProgress => status == 'in_progress';

  String get statusLabel => switch (status) {
        'submitted' || 'pending' => 'بانتظار المعالجة',
        'approved' => 'تمت الموافقة',
        'in_progress' => 'قيد التنفيذ',
        'completed' => 'مكتمل',
        'cancelled' => 'ملغي',
        'rejected' => 'مرفوض',
        _ => status,
      };

  String get approvalLabel => switch (ownerApprovalStatus) {
        'approved' => 'موافق عليه',
        'rejected' => 'مرفوض',
        _ => estimatedCost == null ? 'بانتظار التسعير' : 'بانتظار موافقة المالك',
      };

  String get priorityLabel => switch (priority) {
        'emergency' || 'urgent' => 'عاجل',
        'high' => 'مرتفع',
        'low' => 'منخفض',
        _ => 'متوسط',
      };

  String get categoryLabel => maintenanceCategories[category] ?? 'أخرى';
}

const Map<String, String> maintenanceCategories = {
  'electricity': 'كهرباء',
  'plumbing': 'صحيات',
  'internet': 'إنترنت',
  'ac': 'تكييف',
  'paint': 'صبغ',
  'elevator': 'مصعد',
  'cleaning': 'تنظيف',
  'other': 'أخرى',
};

const Map<String, IconData> maintenanceCategoryIcons = {
  'electricity': Icons.bolt_rounded,
  'plumbing': Icons.water_drop_rounded,
  'internet': Icons.wifi_rounded,
  'ac': Icons.ac_unit_rounded,
  'paint': Icons.format_paint_rounded,
  'elevator': Icons.elevator_rounded,
  'cleaning': Icons.cleaning_services_rounded,
  'other': Icons.handyman_rounded,
};

class MaintenanceMessage {
  final String id;
  final String requestId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final String? senderName;

  const MaintenanceMessage({
    required this.id,
    required this.requestId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.senderName,
  });

  factory MaintenanceMessage.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] is Map ? Map<String, dynamic>.from(map['profiles'] as Map) : null;
    return MaintenanceMessage(
      id: map['id'].toString(),
      requestId: map['request_id'].toString(),
      senderId: map['sender_id'].toString(),
      body: _s(map['body']) ?? '',
      createdAt: _dt(map['created_at']) ?? DateTime.now(),
      senderName: profile == null ? null : _s(profile['full_name']),
    );
  }
}

class TenantRecord {
  final AppProfile profile;
  final Apartment apartment;
  final Lease? lease;
  final double paidThisMonth;

  const TenantRecord({
    required this.profile,
    required this.apartment,
    this.lease,
    this.paidThisMonth = 0,
  });
}

class ArchivedTenantRecord {
  final AppProfile profile;
  final Apartment apartment;
  final Lease? lease;
  final DateTime? moveOutDate;
  final List<Payment> payments;
  final int? paymentsCount;
  final double? paidTotalOverride;

  const ArchivedTenantRecord({
    required this.profile,
    required this.apartment,
    this.lease,
    this.moveOutDate,
    this.payments = const [],
    this.paymentsCount,
    this.paidTotalOverride,
  });

  int get paymentCount => paymentsCount ?? payments.length;

  double get paidTotal =>
      paidTotalOverride ??
      payments.fold<double>(0, (sum, payment) => sum + payment.amount);
}

class LeaseDocument {
  final String id;
  final String leaseId;
  final String tenantId;
  final String? apartmentId;
  final String kind;
  final String storagePath;
  final String? fileName;
  final String? mimeType;
  final int sizeBytes;
  final DateTime? createdAt;
  final String? signedUrl;

  const LeaseDocument({
    required this.id,
    required this.leaseId,
    required this.tenantId,
    required this.kind,
    required this.storagePath,
    this.apartmentId,
    this.fileName,
    this.mimeType,
    this.sizeBytes = 0,
    this.createdAt,
    this.signedUrl,
  });

  factory LeaseDocument.fromMap(Map<String, dynamic> map) {
    return LeaseDocument(
      id: map['id'].toString(),
      leaseId: map['lease_id'].toString(),
      tenantId: map['tenant_id'].toString(),
      apartmentId: _s(map['apartment_id']),
      kind: _s(map['kind']) ?? 'tenant',
      storagePath: _s(map['storage_path']) ?? '',
      fileName: _s(map['file_name']),
      mimeType: _s(map['mime_type']),
      sizeBytes: _i(map['size_bytes']),
      createdAt: _dt(map['created_at']),
    );
  }

  LeaseDocument withSignedUrl(String? url) => LeaseDocument(
        id: id,
        leaseId: leaseId,
        tenantId: tenantId,
        apartmentId: apartmentId,
        kind: kind,
        storagePath: storagePath,
        fileName: fileName,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
        createdAt: createdAt,
        signedUrl: url,
      );

  bool get isContract => kind == 'contract';

  String get kindLabel => isContract ? 'عقد الإيجار' : 'مستمسكات المستأجر';

  bool get isImage {
    final type = mimeType?.toLowerCase() ?? '';
    if (type.startsWith('image/')) return true;
    final name = fileName?.toLowerCase() ?? storagePath.toLowerCase();
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp') ||
        name.endsWith('.heic');
  }
}

class Portfolio {
  final List<Compound> compounds;

  const Portfolio(this.compounds);

  List<Apartment> get apartments => compounds.expand((c) => c.apartments).toList();
  int get total => apartments.length;
  int get occupied => apartments.where((a) => a.status == ApartmentStatus.occupied).length;
  int get vacant => apartments.where((a) => a.status == ApartmentStatus.vacant).length;
  int get maintenance => apartments.where((a) => a.status == ApartmentStatus.maintenance).length;
  int get reserved => apartments.where((a) => a.status == ApartmentStatus.reserved).length;
  double get monthlyExpected => apartments
      .where((a) => a.status == ApartmentStatus.occupied)
      .fold(0, (sum, a) => sum + a.rentAmount);
  double get occupancyRate => total == 0 ? 0 : occupied / total;
  List<String> get apartmentIds => apartments.map((a) => a.id).toList();
  List<Building> get buildings => compounds.expand((c) => c.buildings).toList();
  int get buildingsCount => buildings.length;
}

class OwnerSnapshot {
  final AppProfile owner;
  final Portfolio portfolio;
  final List<MaintenanceRequest> requests;
  final List<Payment> payments;
  final List<TenantRecord> tenants;
  final List<ArchivedTenantRecord> archivedTenants;

  const OwnerSnapshot({
    required this.owner,
    required this.portfolio,
    required this.requests,
    required this.payments,
    required this.tenants,
    this.archivedTenants = const [],
  });

  List<MaintenanceRequest> get pendingApprovals =>
      requests.where((r) => r.needsOwnerApproval).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));

  List<MaintenanceRequest> get openRequests => requests.where((r) => r.isOpen).toList();

  double get collectedThisMonth {
    final now = DateTime.now();
    return payments
        .where((p) => p.paymentDate.year == now.year && p.paymentDate.month == now.month)
        .fold(0, (sum, p) => sum + p.amount);
  }

  double get collectionRate {
    final expected = portfolio.monthlyExpected;
    return expected == 0 ? 0 : (collectedThisMonth / expected).clamp(0, 1);
  }

  int get overdueTenants {
    var count = 0;
    for (final tenant in tenants) {
      final lease = tenant.lease;
      if (lease == null || !lease.isActive) continue;
      if (tenant.paidThisMonth <= 0 && nextDueDate(lease).isBefore(DateTime.now())) {
        count++;
      }
    }
    return count;
  }
}

class ManagerSnapshot {
  final AppProfile manager;
  final Portfolio portfolio;
  final List<MaintenanceRequest> requests;
  final List<TenantRecord> tenants;
  final List<ArchivedTenantRecord> archivedTenants;
  final List<Lease> pendingLeases;
  final List<Payment> payments;

  const ManagerSnapshot({
    required this.manager,
    required this.portfolio,
    required this.requests,
    required this.tenants,
    this.archivedTenants = const [],
    required this.pendingLeases,
    this.payments = const [],
  });

  List<MaintenanceRequest> get activeRequests => requests.where((r) => r.isOpen).toList()
    ..sort((a, b) => _priorityWeight(b).compareTo(_priorityWeight(a)));

  List<MaintenanceRequest> get awaitingApproval =>
      requests.where((r) => r.needsOwnerApproval).toList();

  List<MaintenanceRequest> get readyToExecute =>
      requests.where((r) => r.isApproved && r.status != 'completed').toList();

  int get urgentCount =>
      requests.where((r) => r.isOpen && (r.priority == 'emergency' || r.priority == 'urgent')).length;
}

int _priorityWeight(MaintenanceRequest r) {
  switch (r.priority) {
    case 'emergency':
    case 'urgent':
      return 4;
    case 'high':
      return 3;
    case 'low':
      return 1;
    default:
      return 2;
  }
}

class TenantSnapshot {
  final AppProfile tenant;
  final Apartment? apartment;
  final Lease? lease;
  final AppProfile? manager;
  final List<Payment> payments;
  final List<MaintenanceRequest> requests;

  const TenantSnapshot({
    required this.tenant,
    this.apartment,
    this.lease,
    this.manager,
    this.payments = const [],
    this.requests = const [],
  });

  bool get isLinked => apartment != null && lease != null && lease!.isActive;
  bool get isPending => lease != null && lease!.isPending;
  double get paidThisMonth {
    final now = DateTime.now();
    return payments
        .where((p) => p.paymentDate.year == now.year && p.paymentDate.month == now.month)
        .fold(0, (sum, p) => sum + p.amount);
  }
}

// ------------------------------------------------------------- owner dashboard

class MemberRow {
  final String id;
  final String fullName;
  final String phoneNumber;
  final String? email;
  final UserRole role;
  final bool isActive;
  final String scope;
  final DateTime? createdAt;

  const MemberRow({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
    required this.isActive,
    required this.scope,
    this.email,
    this.createdAt,
  });

  factory MemberRow.fromMap(Map<String, dynamic> map) => MemberRow(
        id: map['id'].toString(),
        fullName: _s(map['full_name']) ?? 'عضو',
        phoneNumber: _s(map['phone_number']) ?? '',
        email: _s(map['email']),
        role: roleFrom(_s(map['role'])),
        isActive: _b(map['is_active'], true),
        scope: _s(map['scope']) ?? 'بدون تعيين',
        createdAt: _dt(map['created_at']),
      );
}

class Invoice {
  final String id;
  final String leaseId;
  final String apartmentId;
  final String tenantId;
  final String number;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final double rentAmount;
  final double utilitiesAmount;
  final double maintenanceAmount;
  final double otherCharges;
  final double totalAmount;
  final double paidAmount;
  final String status;
  final String? notes;
  final DateTime? createdAt;
  final String? tenantName;
  final String? apartmentLabel;
  final String? compoundName;
  final AppCountry country;

  const Invoice({
    required this.id,
    required this.leaseId,
    required this.apartmentId,
    required this.tenantId,
    required this.number,
    required this.invoiceDate,
    required this.totalAmount,
    required this.paidAmount,
    required this.status,
    this.dueDate,
    this.rentAmount = 0,
    this.utilitiesAmount = 0,
    this.maintenanceAmount = 0,
    this.otherCharges = 0,
    this.notes,
    this.createdAt,
    this.tenantName,
    this.apartmentLabel,
    this.compoundName,
    this.country = AppCountry.iq,
  });

  factory Invoice.fromMap(Map<String, dynamic> map) {
    final tenant = map['profiles'] is Map
        ? Map<String, dynamic>.from(map['profiles'] as Map)
        : null;
    final apartment = map['apartments'] is Map
        ? Map<String, dynamic>.from(map['apartments'] as Map)
        : null;
    String? label;
    String? compound;
    var country = AppCountry.iq;
    if (apartment != null) {
      final floor = apartment['floors'] is Map
          ? Map<String, dynamic>.from(apartment['floors'] as Map)
          : null;
      final building = floor?['buildings'] is Map
          ? Map<String, dynamic>.from(floor!['buildings'] as Map)
          : null;
      final compoundMap = building?['compounds'] is Map
          ? Map<String, dynamic>.from(building!['compounds'] as Map)
          : null;
      label = apartmentDisplayName(_s(apartment['unit_number']));
      if (building?['name'] != null) label = '$label · ${building!['name']}';
      compound = _s(compoundMap?['name']);
      country = AppCountry.fromCode(_s(compoundMap?['country']));
    }
    return Invoice(
      id: map['id'].toString(),
      leaseId: map['lease_id']?.toString() ?? '',
      apartmentId: map['apartment_id'].toString(),
      tenantId: map['tenant_id'].toString(),
      number: _s(map['invoice_number']) ?? '—',
      invoiceDate: _dt(map['invoice_date']) ?? DateTime.now(),
      dueDate: _dt(map['due_date']),
      rentAmount: _d(map['rent_amount']),
      utilitiesAmount: _d(map['utilities_amount']),
      maintenanceAmount: _d(map['maintenance_amount']),
      otherCharges: _d(map['other_charges']),
      totalAmount: _d(map['total_amount']),
      paidAmount: _d(map['paid_amount']),
      status: _s(map['status']) ?? 'pending',
      notes: _s(map['notes']),
      createdAt: _dt(map['created_at']),
      tenantName: _s(tenant?['full_name']),
      apartmentLabel: label,
      compoundName: compound,
      country: country,
    );
  }

  double get remaining => (totalAmount - paidAmount).clamp(0, double.infinity).toDouble();

  bool get isPaid => status == 'paid' || remaining <= 0.5;

  bool get isOverdue =>
      !isPaid &&
      (status == 'overdue' ||
          (dueDate != null && dueDate!.isBefore(DateTime.now())));

  String get statusLabel {
    if (isPaid) return 'مسددة';
    if (isOverdue) return 'متأخرة';
    if (status == 'partial') return 'جزئية';
    return 'بانتظار السداد';
  }
}

class Expense {
  final String id;
  final String compoundId;
  final String? buildingId;
  final String category;
  final String title;
  final double amount;
  final DateTime date;
  final String? notes;
  final DateTime? createdAt;
  final String? compoundName;
  final String? buildingName;
  final String? createdBy;
  final AppCountry country;

  const Expense({
    required this.id,
    required this.compoundId,
    required this.category,
    required this.title,
    required this.amount,
    required this.date,
    this.buildingId,
    this.notes,
    this.createdAt,
    this.compoundName,
    this.buildingName,
    this.createdBy,
    this.country = AppCountry.iq,
  });

  factory Expense.fromMap(Map<String, dynamic> map) {
    final compound = map['compounds'] is Map
        ? Map<String, dynamic>.from(map['compounds'] as Map)
        : null;
    final building = map['buildings'] is Map
        ? Map<String, dynamic>.from(map['buildings'] as Map)
        : null;
    return Expense(
      id: map['id'].toString(),
      compoundId: map['compound_id'].toString(),
      buildingId: _s(map['building_id']),
      category: _s(map['category']) ?? 'general',
      title: _s(map['title']) ?? 'مصروف',
      amount: _d(map['amount']),
      date: _dt(map['expense_date']) ?? DateTime.now(),
      notes: _s(map['notes']),
      createdAt: _dt(map['created_at']),
      compoundName: _s(compound?['name']),
      buildingName: _s(building?['name']),
      createdBy: _s(map['created_by']),
      country: AppCountry.fromCode(_s(compound?['country'])),
    );
  }

  String get scopeLabel {
    final building = buildingName?.trim();
    if (building != null && building.isNotEmpty) return building;
    return compoundName?.trim().isNotEmpty == true
        ? 'عام · ${compoundName!.trim()}'
        : 'عام';
  }

  String get categoryLabel => expenseCategories[category] ?? 'عام';
}

const Map<String, String> expenseCategories = {
  'general': 'عام',
  'maintenance': 'صيانة',
  'cleaning': 'تنظيف',
  'utilities': 'خدمات',
  'salaries': 'رواتب',
  'security': 'أمن',
  'taxes': 'ضرائب',
  'other': 'أخرى',
};

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic> data;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.data = const {},
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> data = const {};
    final raw = map['data'];
    if (raw is Map) {
      data = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      } catch (_) {
        // ignore malformed payloads
      }
    }
    return AppNotification(
      id: map['id'].toString(),
      title: _s(map['title']) ?? '',
      body: _s(map['body']) ?? '',
      type: _s(map['notification_type']) ?? 'general',
      isRead: _b(map['is_read']),
      createdAt: _dt(map['created_at']) ?? DateTime.now(),
      data: data,
    );
  }

  IconData get icon => switch (type) {
        'maintenance' => Icons.build_circle_rounded,
        'lease' => Icons.key_rounded,
        'payment' => Icons.payments_rounded,
        'invoice' => Icons.receipt_long_rounded,
        'announcement' => Icons.campaign_rounded,
        _ => Icons.notifications_rounded,
      };

  Color get color => switch (type) {
        'maintenance' => AppColors.pending,
        'lease' => AppColors.info,
        'payment' => AppColors.occupied,
        'invoice' => AppColors.gold,
        'announcement' => AppColors.reserved,
        _ => AppColors.textSecondary,
      };
}

class Announcement {
  final String id;
  final String title;
  final String content;
  final DateTime? publishedAt;
  final String? compoundName;
  final AppCountry country;

  const Announcement({
    required this.id,
    required this.title,
    required this.content,
    this.publishedAt,
    this.compoundName,
    this.country = AppCountry.iq,
  });

  factory Announcement.fromMap(Map<String, dynamic> map) {
    final compound = map['compounds'] is Map
        ? Map<String, dynamic>.from(map['compounds'] as Map)
        : null;
    return Announcement(
      id: map['id'].toString(),
      title: _s(map['title']) ?? '',
      content: _s(map['content']) ?? '',
      publishedAt: _dt(map['published_at']) ?? _dt(map['created_at']),
      compoundName: _s(compound?['name']),
      country: AppCountry.fromCode(_s(compound?['country'])),
    );
  }
}

class ApartmentManagerAssignment {
  final String apartmentId;
  final String managerId;
  final String fullName;
  final String phoneNumber;
  final String unitLabel;
  final String compoundId;
  final String compoundName;

  const ApartmentManagerAssignment({
    required this.apartmentId,
    required this.managerId,
    required this.fullName,
    required this.phoneNumber,
    required this.unitLabel,
    required this.compoundId,
    required this.compoundName,
  });

  factory ApartmentManagerAssignment.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] is Map
        ? Map<String, dynamic>.from(map['profiles'] as Map)
        : null;
    final apartment = map['apartments'] is Map
        ? Map<String, dynamic>.from(map['apartments'] as Map)
        : null;
    final floor = apartment?['floors'] is Map
        ? Map<String, dynamic>.from(apartment!['floors'] as Map)
        : null;
    final building = floor?['buildings'] is Map
        ? Map<String, dynamic>.from(floor!['buildings'] as Map)
        : null;
    final compound = building?['compounds'] is Map
        ? Map<String, dynamic>.from(building!['compounds'] as Map)
        : null;
    final unit = _s(apartment?['unit_number']) ?? '—';
    final buildingName = _s(building?['name']);
    final unitName = apartmentDisplayName(unit);
    return ApartmentManagerAssignment(
      apartmentId: map['apartment_id'].toString(),
      managerId: map['manager_id'].toString(),
      fullName: _s(profile?['full_name']) ?? 'مدير',
      phoneNumber: _s(profile?['phone_number']) ?? '',
      unitLabel: buildingName == null ? unitName : '$unitName · $buildingName',
      compoundId: _s(compound?['id']) ?? _s(building?['compound_id']) ?? '',
      compoundName: _s(compound?['name']) ?? 'عقار',
    );
  }
}

// ---------------------------------------------------------------- date helpers

DateTime nextDueDate(Lease lease, [DateTime? from]) {
  final now = from ?? DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = lease.startDate.day.clamp(1, 28);
  var due = DateTime(today.year, today.month, day);
  if (due.isBefore(today)) {
    due = DateTime(today.year, today.month + 1, day);
  }
  // Never go beyond the lease end when it can be helped.
  if (due.isAfter(lease.endDate) && lease.endDate.isAfter(today)) {
    return lease.endDate;
  }
  return due;
}

int daysUntil(DateTime date, [DateTime? from]) {
  final now = from ?? DateTime.now();
  final a = DateTime(now.year, now.month, now.day);
  final b = DateTime(date.year, date.month, date.day);
  return b.difference(a).inDays;
}

bool isSameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;
