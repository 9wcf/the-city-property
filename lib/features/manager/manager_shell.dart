import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models.dart';
import '../shared/notifications_screen.dart';
import '../shared/portfolio_screen.dart';
import '../shared/profile_screen.dart';
import 'add_tenant_screen.dart';
import 'manager_accounting_screen.dart';
import 'manager_overview_screen.dart';
import 'manager_requests_screen.dart';
import 'manager_tenants_screen.dart';
import '../../core/widgets/premium_widgets.dart';

class ManagerShell extends ConsumerStatefulWidget {
  const ManagerShell({super.key, required this.profile});

  final AppProfile profile;

  @override
  ConsumerState<ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends ConsumerState<ManagerShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final activeCount = ref.watch(managerSnapshotProvider).maybeWhen(
          data: (snapshot) => snapshot.activeRequests.length,
          orElse: () => 0,
        );
    final unreadNotifications = ref.watch(unreadNotificationsProvider).maybeWhen(
          data: (value) => value,
          orElse: () => 0,
        );
    final pages = [
      ManagerOverviewScreen(profile: widget.profile, onNavigate: (index) => setState(() => _index = index)),
      ManagerRequestsScreen(profile: widget.profile),
      PortfolioScreen(viewer: widget.profile),
      ManagerTenantsScreen(profile: widget.profile),
      ManagerAccountingScreen(profile: widget.profile),
      const NotificationsScreen(),
      ProfileScreen(profile: widget.profile, subtitle: 'مدير العقارات'),
    ];
    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: PremiumBackground(
        child: SafeArea(
          bottom: false,
          child: IndexedStack(index: _index, children: pages),
        ),
      ),
      floatingActionButton: _index == 3
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddTenantScreen(manager: widget.profile),
                  ),
                );
                ref.invalidate(managerSnapshotProvider);
                ref.invalidate(ownerSnapshotProvider);
              },
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.navy900,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text(
                'إضافة مستأجر',
                style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w800),
              ),
            )
          : null,
      bottomNavigationBar: BottomNavBar(
        currentIndex: _index,
        onSelect: (index) => setState(() => _index = index),
        items: [
          const NavItem(label: 'الرئيسية', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded),
          NavItem(
            label: 'الطلبات',
            icon: Icons.build_outlined,
            activeIcon: Icons.build_rounded,
            badge: activeCount,
          ),
          const NavItem(label: 'العقارات', icon: Icons.domain_outlined, activeIcon: Icons.domain_rounded),
          const NavItem(label: 'المستأجرون', icon: Icons.people_outline_rounded, activeIcon: Icons.people_rounded),
          const NavItem(
            label: 'الحسابات',
            icon: Icons.account_balance_wallet_outlined,
            activeIcon: Icons.account_balance_wallet_rounded,
          ),
          NavItem(
            label: 'الإشعارات',
            icon: Icons.notifications_none_rounded,
            activeIcon: Icons.notifications_rounded,
            badge: unreadNotifications,
          ),
          const NavItem(label: 'حسابي', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded),
        ],
      ),
    );
  }
}
