import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:the_city_property/app/providers.dart';
import 'package:the_city_property/core/theme/app_theme.dart';
import 'package:the_city_property/data/models.dart';
import 'package:the_city_property/features/owner/owner_web_shell.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  testWidgets('owner web dashboard renders every section without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final profile = AppProfile(
      id: 'owner-1',
      fullName: 'مالك تجريبي',
      phoneNumber: '07701234567',
      role: UserRole.owner,
    );

    const apartment = Apartment(
      id: 'apt-1',
      floorId: 'floor-1',
      unitNumber: '101',
      rentAmount: 750000,
      status: ApartmentStatus.occupied,
      roomCount: 2,
      floorNumber: 1,
      buildingName: 'عمارة A',
      compoundName: 'مجمع النخيل',
      compoundId: 'compound-1',
    );
    final apartments = <Apartment>[
      apartment,
      for (var i = 2; i <= 13; i++)
        Apartment(
          id: 'apt-$i',
          floorId: 'floor-1',
          unitNumber: '${100 + i}',
          rentAmount: 750000,
          status: ApartmentStatus.vacant,
          roomCount: 2,
          floorNumber: 1,
          buildingName: 'عمارة A',
          compoundName: 'مجمع النخيل',
          compoundId: 'compound-1',
        ),
    ];
    final floor = Floor(
      id: 'floor-1',
      buildingId: 'building-1',
      floorNumber: 1,
      apartments: apartments,
    );
    final building = Building(
      id: 'building-1',
      compoundId: 'compound-1',
      name: 'عمارة A',
      floors: [floor],
    );
    final compound = Compound(
      id: 'compound-1',
      name: 'مجمع النخيل',
      ownerId: 'owner-1',
      buildings: [building],
    );
    final portfolio = Portfolio([compound]);

    final now = DateTime.now();
    final lease = Lease(
      id: 'lease-1',
      apartmentId: 'apt-1',
      tenantId: 'tenant-1',
      startDate: now.subtract(const Duration(days: 45)),
      endDate: now.add(const Duration(days: 320)),
      monthlyRent: 750000,
      depositAmount: 750000,
      status: 'active',
    );
    const tenantProfile = AppProfile(
      id: 'tenant-1',
      fullName: 'مستأجر تجريبي',
      phoneNumber: '07701112223',
      role: UserRole.tenant,
    );
    final snapshot = OwnerSnapshot(
      owner: profile,
      portfolio: portfolio,
      requests: const [],
      payments: const [],
      tenants: [
        TenantRecord(
          profile: tenantProfile,
          apartment: apartment,
          lease: lease,
          paidThisMonth: 300000,
        ),
      ],
      archivedTenants: [
        ArchivedTenantRecord(
          profile: const AppProfile(
            id: 'tenant-old',
            fullName: 'مستأجر مؤرشف',
            phoneNumber: '07701112299',
            role: UserRole.tenant,
          ),
          apartment: apartment,
          lease: Lease(
            id: 'lease-old',
            apartmentId: 'apt-1',
            tenantId: 'tenant-old',
            startDate: DateTime(2025, 1, 1),
            endDate: DateTime(2025, 12, 31),
            monthlyRent: 750000,
            status: 'terminated',
          ),
          moveOutDate: DateTime(2026, 1, 1),
          payments: [
            Payment(
              id: 'pay-old',
              tenantId: 'tenant-old',
              amount: 1500000,
              paymentDate: DateTime(2025, 12, 1),
              paymentMethod: 'cash',
            ),
          ],
        ),
      ],
    );

    final invoice = Invoice(
      id: 'invoice-1',
      leaseId: 'lease-1',
      apartmentId: 'apt-1',
      tenantId: 'tenant-1',
      number: 'INV-202611-ABC123',
      invoiceDate: DateTime(now.year, now.month, 5),
      dueDate: DateTime(now.year, now.month, 9),
      rentAmount: 750000,
      utilitiesAmount: 50000,
      totalAmount: 800000,
      paidAmount: 300000,
      status: 'partial',
      tenantName: 'مستأجر تجريبي',
      apartmentLabel: 'شقة 101 · عمارة A',
      compoundName: 'مجمع النخيل',
    );
    final expense = Expense(
      id: 'expense-1',
      compoundId: 'compound-1',
      category: 'maintenance',
      title: 'صيانة مصعد',
      amount: 120000,
      date: DateTime(now.year, now.month, 6),
      compoundName: 'مجمع النخيل',
    );

    final dashboard = OwnerDashboardData(
      snapshot: snapshot,
      members: const [
        MemberRow(
          id: 'tenant-1',
          fullName: 'مستأجر تجريبي',
          phoneNumber: '07701112223',
          role: UserRole.tenant,
          isActive: true,
          scope: 'شقة 101 · عمارة A',
        ),
        MemberRow(
          id: 'manager-1',
          fullName: 'مدير تجريبي',
          phoneNumber: '07701112224',
          role: UserRole.manager,
          isActive: true,
          scope: 'مجمع النخيل',
        ),
      ],
      invoices: [invoice],
      expenses: [expense],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ownerSnapshotProvider.overrideWith((ref) async => snapshot),
          ownerDashboardProvider.overrideWith((ref) async => dashboard),
          unreadNotificationsProvider.overrideWith((ref) async => 2),
          notificationsProvider.overrideWith((ref) async => [
                AppNotification(
                  id: 'n1',
                  title: 'فاتورة جديدة',
                  body: 'صدرت فاتورة بمبلغ 800000 د.ع',
                  type: 'invoice',
                  isRead: false,
                  createdAt: DateTime(2026, 11, 5),
                ),
              ]),
          announcementsProvider.overrideWith((ref) async => const [
                Announcement(
                  id: 'ann-1',
                  title: 'صيانة المصعد',
                  content: 'ستتم صيانة المصعد يوم السبت.',
                  compoundName: 'مجمع النخيل',
                ),
              ]),
          compoundManagersProvider.overrideWith((ref) async => [
                (
                  compoundId: 'compound-1',
                  managerId: 'manager-1',
                  fullName: 'مدير تجريبي',
                  phoneNumber: '07701112224',
                ),
              ]),
          apartmentManagersProvider.overrideWith((ref) async => const [
                ApartmentManagerAssignment(
                  apartmentId: 'apt-1',
                  managerId: 'manager-1',
                  fullName: 'مدير تجريبي',
                  phoneNumber: '07701112224',
                  unitLabel: 'شقة 101 · عمارة A',
                  compoundId: 'compound-1',
                  compoundName: 'مجمع النخيل',
                ),
              ]),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
          home: OwnerWebShell(profile: profile),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('عقارات العراق'), findsOneWidget);
    expect(find.text('عقارات الإمارات'), findsOneWidget);
    expect(find.text('عقارات أمريكا'), findsOneWidget);
    await tester.tap(find.text('دخول لوحة العراق'));
    await tester.pumpAndSettle();

    expect(find.text('مرحباً، مالك تجريبي'), findsOneWidget);
    expect(tester.takeException(), isNull);

    const sidebarLabels = [
      'نظرة عامة',
      'الأعضاء',
      'المستأجرون',
      'المديرون',
      'المحاسبة',
      'الإشعارات',
      'الطلبات والموافقات',
      'العقارات',
      'حسابي',
    ];
    for (final label in sidebarLabels) {
      expect(find.text(label), findsWidgets, reason: 'sidebar item $label');
    }

    const sections = {
      'الأعضاء': 'قائمة الأعضاء',
      'المستأجرون': 'المستأجرون الحاليون',
      'المديرون': 'إدارة المديرين',
      'المحاسبة': 'تفصيل الشهر',
      'الإشعارات': 'الإشعارات والتواصل',
      'الطلبات والموافقات': 'الموافقات',
      'العقارات': 'إضافة عمارة',
    };
    for (final entry in sections.entries) {
      await tester.tap(find.text(entry.key).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'section ${entry.key}');
      expect(find.text(entry.value), findsWidgets,
          reason: 'section ${entry.key} did not render');
    }

    await tester.tap(find.text('المديرون').first);
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('عبر العقار'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('المستأجرون').first);
    await tester.pumpAndSettle();
    expect(find.text('المستأجرون المؤرشفون'), findsWidgets);
    expect(find.text('مستأجر مؤرشف'), findsOneWidget);
    await tester.tap(find.byTooltip('حذف المؤرشف نهائياً'));
    await tester.pumpAndSettle();
    expect(find.text('حذف المستأجر المؤرشف'), findsOneWidget);
    expect(find.text('حذف نهائي'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('العقارات').first);
    await tester.pumpAndSettle();
    expect(find.text('إضافة عقار'), findsOneWidget);
    expect(find.text('عرض العمارات'), findsOneWidget);
    await tester.tap(find.text('عرض العمارات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('عمارة A').first);
    await tester.pumpAndSettle();
    expect(find.text('شقة 101'), findsWidgets);
    expect(find.text('الوصف والتفاصيل'), findsOneWidget);
    expect(find.byTooltip('تعديل'), findsNWidgets(13));
    expect(find.text('شقة 113'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('الزر السحري'));
    await tester.pumpAndSettle();
    expect(find.text('الزر السحري — كل الشقق'), findsOneWidget);
    expect(find.text('إجمالي الشقق'), findsOneWidget);
    expect(find.text('متبقي إيجار هذا الشهر'), findsOneWidget);
    expect(find.text('مستأجر تجريبي'), findsWidgets);
    expect(find.text('متبقي هذا الشهر'), findsWidgets);
    expect(find.text('متبقي من قيمة العقد'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.textContaining('فارغة (').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('كل التفاصيل').first);
    await tester.pumpAndSettle();
    expect(find.text('بيانات الشقة'), findsOneWidget);
    expect(find.text('الوضع المالي'), findsOneWidget);
    expect(find.text('متاحة للإيجار'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
