import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';
import '../auth/splash_screen.dart';
import '../shared/notifications_screen.dart';
import '../shared/profile_screen.dart';
import 'new_request_screen.dart';
import 'tenant_home_screen.dart';
import 'tenant_link_screen.dart';
import 'tenant_payments_screen.dart';
import 'tenant_requests_screen.dart';

class TenantShell extends ConsumerStatefulWidget {
  const TenantShell({super.key, required this.profile});

  final AppProfile profile;

  @override
  ConsumerState<TenantShell> createState() => _TenantShellState();
}

class _TenantShellState extends ConsumerState<TenantShell> {
  int _index = 0;

  Future<void> _openNewRequest(TenantSnapshot snapshot) async {
    final apartment = snapshot.apartment;
    if (apartment == null) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NewRequestScreen(tenant: widget.profile, apartment: apartment),
      ),
    );
    if (result == true) {
      ref.invalidate(tenantSnapshotProvider);
      setState(() => _index = 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshotAsync = ref.watch(tenantSnapshotProvider);
    return snapshotAsync.when(
      loading: () => const SplashScreen(message: 'جاري تحميل بيانات شقتك…'),
      error: (error, _) => Scaffold(
        backgroundColor: AppColors.navy900,
        body: PremiumBackground(
          child: SafeArea(
            child: ErrorView(
              message: friendlyError(error),
              onRetry: () => ref.invalidate(tenantSnapshotProvider),
            ),
          ),
        ),
      ),
      data: (snapshot) {
        if (!snapshot.isLinked) {
          return TenantLinkScreen(
            profile: widget.profile,
            pendingLease: snapshot.isPending ? snapshot.lease : null,
          );
        }

        final openRequests = snapshot.requests.where((r) => r.isOpen).length;
        final unreadNotifications = ref.watch(unreadNotificationsProvider).maybeWhen(
              data: (value) => value,
              orElse: () => 0,
            );
        final pages = [
          TenantHomeScreen(
            profile: widget.profile,
            snapshot: snapshot,
            onNavigate: (index) => setState(() => _index = index),
            onNewRequest: () => _openNewRequest(snapshot),
          ),
          TenantRequestsScreen(
            profile: widget.profile,
            onNewRequest: () => _openNewRequest(snapshot),
          ),
          TenantPaymentsScreen(profile: widget.profile, snapshot: snapshot),
          const NotificationsScreen(),
          ProfileScreen(
            profile: widget.profile,
            subtitle: snapshot.apartment?.label,
          ),
        ];

        return Scaffold(
          backgroundColor: AppColors.navy900,
          body: PremiumBackground(
            child: SafeArea(
              bottom: false,
              child: IndexedStack(index: _index, children: pages),
            ),
          ),
          floatingActionButton: _index == 1
              ? FloatingActionButton.extended(
                  onPressed: () => _openNewRequest(snapshot),
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.navy900,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'طلب جديد',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w800),
                  ),
                )
              : null,
          bottomNavigationBar: BottomNavBar(
            currentIndex: _index,
            onSelect: (index) => setState(() => _index = index),
            items: [
              const NavItem(label: 'الرئيسية', icon: Icons.home_outlined, activeIcon: Icons.home_rounded),
              NavItem(
                label: 'طلباتي',
                icon: Icons.build_outlined,
                activeIcon: Icons.build_rounded,
                badge: openRequests,
              ),
              const NavItem(label: 'المدفوعات', icon: Icons.payments_outlined, activeIcon: Icons.payments_rounded),
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
      },
    );
  }
}
