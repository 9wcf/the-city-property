import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:the_city_property/app/providers.dart';
import 'package:the_city_property/core/theme/app_theme.dart';
import 'package:the_city_property/data/models.dart';
import 'package:the_city_property/features/manager/manager_tenants_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  testWidgets('manager tenants screen shows archived tenants and their record',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const manager = AppProfile(
      id: 'manager-1',
      fullName: 'مدير تجريبي',
      phoneNumber: '07701112220',
      role: UserRole.manager,
    );
    const tenant = AppProfile(
      id: 'tenant-1',
      fullName: 'محمد علي',
      phoneNumber: '07701112223',
      role: UserRole.tenant,
    );
    const apartment = Apartment(
      id: 'apt-1',
      floorId: 'floor-1',
      buildingId: 'building-1',
      unitNumber: '1',
      rentAmount: 500000,
      status: ApartmentStatus.vacant,
      buildingName: 'عمارة شارع 42',
    );
    const portfolio = Portfolio([
      Compound(
        id: 'compound-1',
        name: 'مجمع النخيل',
        ownerId: 'owner-1',
        buildings: [
          Building(
            id: 'building-1',
            compoundId: 'compound-1',
            name: 'عمارة شارع 42',
            floors: [
              Floor(
                id: 'floor-1',
                buildingId: 'building-1',
                floorNumber: 1,
                apartments: [apartment],
              ),
            ],
          ),
        ],
      ),
    ]);
    final lease = Lease(
      id: 'lease-1',
      apartmentId: 'apt-1',
      tenantId: 'tenant-1',
      startDate: DateTime(2026, 11, 8),
      endDate: DateTime(2026, 11, 9),
      monthlyRent: 500000,
      status: 'terminated',
      notes: 'إخلاء: عدم التزام المستأجر بدفع الإيجارات في وقتها المحدد',
    );
    final snapshot = ManagerSnapshot(
      manager: manager,
      portfolio: portfolio,
      requests: const [],
      tenants: const [],
      archivedTenants: [
        ArchivedTenantRecord(
          profile: tenant,
          apartment: apartment,
          lease: lease,
          moveOutDate: DateTime(2026, 11, 7),
          payments: [
            Payment(
              id: 'pay-1',
              tenantId: 'tenant-1',
              amount: 500000,
              paymentDate: DateTime(2026, 10, 5),
              paymentMethod: 'cash',
            ),
          ],
        ),
      ],
      pendingLeases: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          managerSnapshotProvider.overrideWith((ref) async => snapshot),
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(bottom: 34),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
          home: const Scaffold(body: ManagerTenantsScreen(profile: manager)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الأرشيف (1)'), findsOneWidget);
    await tester.tap(find.text('الأرشيف (1)'));
    await tester.pumpAndSettle();

    expect(find.text('محمد علي'), findsOneWidget);
    expect(find.text('مؤرشف'), findsOneWidget);
    expect(find.textContaining('مدفوعات'), findsWidgets);

    await tester.tap(find.text('محمد علي'));
    await tester.pumpAndSettle();

    expect(find.text('تاريخ الإخلاء'), findsOneWidget);
    expect(find.text('إجمالي المدفوعات'), findsOneWidget);
    expect(find.text('المستمسكات وصور العقد'), findsOneWidget);
    expect(find.textContaining('إخلاء: عدم التزام'), findsOneWidget);

    final paddedSheet = tester
        .widgetList<Container>(find.byType(Container))
        .where((container) =>
            container.padding == const EdgeInsets.fromLTRB(24, 24, 24, 58));
    expect(paddedSheet, isNotEmpty,
        reason: 'أسفل النافذة يجب أن يضيف ارتفاع شريط التنقل 34');
    expect(tester.takeException(), isNull);
  });
}
