import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:the_city_property/app/providers.dart';
import 'package:the_city_property/core/theme/app_theme.dart';
import 'package:the_city_property/core/widgets/premium_widgets.dart';
import 'package:the_city_property/data/models.dart';
import 'package:the_city_property/features/manager/manager_overview_screen.dart';
import 'package:the_city_property/features/tenant/tenant_home_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  Widget wrap(Widget child, List<Override> overrides) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, home) => Directionality(
          textDirection: TextDirection.rtl,
          child: home ?? const SizedBox.shrink(),
        ),
        home: child,
      ),
    );
  }

  testWidgets('manager dashboard shows only the assigned property',
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
                apartments: [],
              ),
            ],
          ),
        ],
      ),
    ]);
    final snapshot = ManagerSnapshot(
      manager: manager,
      portfolio: portfolio,
      requests: const [],
      tenants: const [],
      pendingLeases: const [],
      payments: const [],
    );

    await tester.pumpWidget(wrap(
      const Scaffold(body: ManagerOverviewScreen(profile: manager, onNavigate: _noopInt)),
      [managerSnapshotProvider.overrideWith((ref) async => snapshot)],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('مسؤول عن: مجمع النخيل'), findsOneWidget);
    expect(find.text('عمارة A'), findsWidgets);
    expect(find.textContaining('لا توجد عمارات موكلة'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seven-tab navigation fits on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(
      Scaffold(
        bottomNavigationBar: BottomNavBar(
          currentIndex: 0,
          onSelect: _noopInt,
          items: const [
            NavItem(label: 'الرئيسية', icon: Icons.dashboard_outlined),
            NavItem(label: 'الطلبات', icon: Icons.build_outlined),
            NavItem(label: 'العقارات', icon: Icons.domain_outlined),
            NavItem(label: 'المستأجرون', icon: Icons.people_outline_rounded),
            NavItem(label: 'الحسابات', icon: Icons.account_balance_wallet_outlined),
            NavItem(label: 'الإشعارات', icon: Icons.notifications_none_rounded),
            NavItem(label: 'حسابي', icon: Icons.person_outline_rounded),
          ],
        ),
      ),
      const [],
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('tenant dashboard shows only the rented apartment and manager',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const tenant = AppProfile(
      id: 'tenant-1',
      fullName: 'مستأجر أول',
      phoneNumber: '07701112223',
      role: UserRole.tenant,
    );
    const manager = AppProfile(
      id: 'manager-1',
      fullName: 'مدير العقار',
      phoneNumber: '07701112220',
      role: UserRole.manager,
    );
    const apartment = Apartment(
      id: 'apt-1',
      floorId: 'floor-1',
      buildingId: 'building-1',
      unitNumber: '101',
      rentAmount: 500000,
      status: ApartmentStatus.occupied,
      buildingName: 'عمارة A',
      compoundName: 'مجمع النخيل',
    );
    final lease = Lease(
      id: 'lease-1',
      apartmentId: 'apt-1',
      tenantId: 'tenant-1',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2027, 1, 1),
      monthlyRent: 500000,
      status: 'active',
    );
    final snapshot = TenantSnapshot(
      tenant: tenant,
      apartment: apartment,
      lease: lease,
      manager: manager,
    );

    await tester.pumpWidget(wrap(
      Scaffold(
        body: TenantHomeScreen(
          profile: tenant,
          snapshot: snapshot,
          onNavigate: _noopInt,
          onNewRequest: _noop,
        ),
      ),
      [tenantSnapshotProvider.overrideWith((ref) async => snapshot)],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('101'), findsWidgets);
    expect(find.text('مدير العقار'), findsOneWidget);
    expect(find.textContaining('لم يتم تعيين مدير'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
void _noopInt(int _) {}
