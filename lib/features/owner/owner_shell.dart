import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/i18n/app_country.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_utils.dart';
import '../../core/widgets/language_toggle.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';
import '../shared/notifications_screen.dart';
import '../shared/portfolio_screen.dart';
import '../shared/profile_screen.dart';
import 'owner_approvals_screen.dart';
import 'owner_country_hub.dart';
import 'owner_finance_screen.dart';
import 'owner_overview_screen.dart';
import 'owner_web_shell.dart';

class OwnerShell extends ConsumerStatefulWidget {
  const OwnerShell({super.key, required this.profile});

  final AppProfile profile;

  @override
  ConsumerState<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends ConsumerState<OwnerShell> {
  int _index = 0;

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content:
            const Text('هل أنت متأكد من رغبتك في تسجيل الخروج من لوحة المالك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('خروج', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(ownerCountryEnteredProvider.notifier).state = false;
      await ref.read(sessionControllerProvider).signOut();
    }
  }

  void _openCountry(AppCountry country) {
    ref.read(ownerCountryProvider.notifier).state = country;
    ref.read(ownerCountryEnteredProvider.notifier).state = true;
    setState(() => _index = 0);
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 1020) {
      return OwnerWebShell(profile: widget.profile);
    }
    if (!ref.watch(ownerCountryEnteredProvider)) {
      return OwnerCountryHub(
        profile: widget.profile,
        onSelected: _openCountry,
        onSignOut: _confirmSignOut,
      );
    }
    final country = ref.watch(ownerCountryProvider);
    final pending = ref.watch(ownerSnapshotProvider).maybeWhen(
          data: (snapshot) {
            final apartmentIds = snapshot.portfolio.apartments
                .where((apartment) => apartment.country == country)
                .map((apartment) => apartment.id)
                .toSet();
            return snapshot.pendingApprovals
                .where((request) => apartmentIds.contains(request.apartmentId))
                .length;
          },
          orElse: () => 0,
        );
    final unread = ref.watch(unreadNotificationsProvider).maybeWhen(
          data: (value) => value,
          orElse: () => 0,
        );
    defaultDisplayCountry = country;

    final pages = [
      OwnerOverviewScreen(
          profile: widget.profile,
          onNavigate: (index) => setState(() => _index = index)),
      PortfolioScreen(viewer: widget.profile),
      OwnerApprovalsScreen(profile: widget.profile),
      OwnerFinanceScreen(profile: widget.profile),
      const NotificationsScreen(),
      ProfileScreen(profile: widget.profile, subtitle: 'مالك العقارات'),
    ];

    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: PremiumBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _WorkspaceBar(
                country: country,
                onCountries: () =>
                    ref.read(ownerCountryEnteredProvider.notifier).state = false,
                onChanged: (value) {
                  ref.read(ownerCountryProvider.notifier).state = value;
                  setState(() => _index = 0);
                },
                onSignOut: _confirmSignOut,
              ),
              Expanded(
                child: IndexedStack(index: _index, children: pages),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _index,
        onSelect: (index) => setState(() => _index = index),
        items: [
          const NavItem(
              label: 'الرئيسية',
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded),
          const NavItem(
              label: 'العقارات',
              icon: Icons.domain_outlined,
              activeIcon: Icons.domain_rounded),
          NavItem(
            label: 'الموافقات',
            icon: Icons.fact_check_outlined,
            activeIcon: Icons.fact_check_rounded,
            badge: pending,
          ),
          const NavItem(
              label: 'المالية',
              icon: Icons.account_balance_wallet_outlined,
              activeIcon: Icons.account_balance_wallet_rounded),
          NavItem(
            label: 'الإشعارات',
            icon: Icons.notifications_none_rounded,
            activeIcon: Icons.notifications_rounded,
            badge: unread,
          ),
          const NavItem(
              label: 'حسابي',
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded),
        ],
      ),
    );
  }
}

class _WorkspaceBar extends StatelessWidget {
  const _WorkspaceBar({
    required this.country,
    required this.onCountries,
    required this.onChanged,
    required this.onSignOut,
  });

  final AppCountry country;
  final VoidCallback onCountries;
  final ValueChanged<AppCountry> onChanged;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: tr('الدول'),
            onPressed: onCountries,
            icon: const Icon(Icons.grid_view_rounded,
                size: 20, color: AppColors.gold),
          ),
          Expanded(
            child: PopupMenuButton<AppCountry>(
              tooltip: tr('الدولة والعملة'),
              initialValue: country,
              onSelected: onChanged,
              itemBuilder: (context) => AppCountry.values
                  .map(
                    (item) => PopupMenuItem<AppCountry>(
                      value: item,
                      child: Text(
                        '${item.flag} ${item.name(english: I18n.isEnglish)} · ${item.currencyCode}',
                      ),
                    ),
                  )
                  .toList(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.gold),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(country.flag, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${country.name(english: I18n.isEnglish)} · ${country.currencyCode}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down_rounded,
                        size: 18, color: AppColors.gold),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          const LanguageToggle(compact: true),
          const SizedBox(width: 4),
          IconButton(
            tooltip: tr('تسجيل الخروج'),
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded,
                size: 19, color: AppColors.danger),
          ),
        ],
      ),
    );
  }
}
