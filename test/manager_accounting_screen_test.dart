import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:the_city_property/app/providers.dart';
import 'package:the_city_property/core/theme/app_theme.dart';
import 'package:the_city_property/data/models.dart';
import 'package:the_city_property/features/manager/manager_accounting_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  testWidgets('manager accounting screen renders its three tabs',
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
      fullName: 'مستأجر أول',
      phoneNumber: '07701112223',
      role: UserRole.tenant,
    );
    const apartment = Apartment(
      id: 'apt-1',
      floorId: 'floor-1',
      buildingId: 'building-1',
      unitNumber: '101',
      rentAmount: 500000,
      status: ApartmentStatus.occupied,
      buildingName: 'عمارة A',
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
            name: 'عمارة A',
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
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2027, 1, 1),
      monthlyRent: 500000,
      status: 'active',
    );
    final snapshot = ManagerSnapshot(
      manager: manager,
      portfolio: portfolio,
      requests: const [],
      tenants: [
        TenantRecord(profile: tenant, apartment: apartment, lease: lease),
      ],
      pendingLeases: const [],
      payments: [
        Payment(
          id: 'pay-1',
          tenantId: 'tenant-1',
          amount: 200000,
          paymentDate: DateTime(DateTime.now().year, DateTime.now().month, 3),
          paymentMethod: 'cash',
        ),
      ],
    );
    final data = ManagerAccountingData(
      snapshot: snapshot,
      invoices: const [],
      expenses: [
        Expense(
          id: 'expense-1',
          compoundId: 'compound-1',
          buildingId: 'building-1',
          category: 'maintenance',
          title: 'صيانة مصعد',
          amount: 150000,
          date: DateTime(DateTime.now().year, DateTime.now().month, 4),
          buildingName: 'عمارة A',
          compoundName: 'مجمع النخيل',
          createdBy: 'manager-1',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          managerAccountingProvider.overrideWith((ref) async => data),
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
          home: const Scaffold(body: ManagerAccountingScreen(profile: manager)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تحصيل الإيجارات'), findsOneWidget);
    expect(find.text('مستأجر أول'), findsWidgets);
    expect(find.text('إضافة دفعة'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('المصاريف').first);
    await tester.pumpAndSettle();
    expect(find.text('إضافة مصروف'), findsOneWidget);
    expect(find.text('صيانة مصعد'), findsOneWidget);
    expect(find.byTooltip('حذف'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('التقرير').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('تقرير البنايات'), findsOneWidget);
    expect(find.text('عمارة A'), findsWidgets);
    expect(find.text('صافي الربح'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
