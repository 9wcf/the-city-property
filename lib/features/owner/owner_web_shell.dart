import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/i18n/app_country.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_utils.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/language_toggle.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';
import '../shared/profile_screen.dart';
import 'owner_approvals_screen.dart';
import 'owner_country_hub.dart';
import 'web/accounting_section.dart';
import 'web/magic_apartments_dialog.dart';
import 'web/managers_section.dart';
import 'web/members_section.dart';
import 'web/notifications_admin_section.dart';
import 'web/overview_section.dart';
import 'web/portfolio_section.dart';
import 'web/tenants_section.dart';
import 'web/web_ui.dart';

class OwnerWebShell extends ConsumerStatefulWidget {
  const OwnerWebShell({super.key, required this.profile});

  final AppProfile profile;

  @override
  ConsumerState<OwnerWebShell> createState() => _OwnerWebShellState();
}

class _OwnerWebShellState extends ConsumerState<OwnerWebShell> {
  OwnerSection _section = OwnerSection.overview;
  final Set<OwnerSection> _visited = {OwnerSection.overview};
  bool _refreshing = false;

  static const _sections = OwnerSection.values;

  void _select(OwnerSection section) {
    if (_section == section) return;
    setState(() {
      _section = section;
      _visited.add(section);
    });
  }

  void _openCountry(AppCountry country) {
    ref.read(ownerCountryProvider.notifier).state = country;
    ref.read(ownerCountryEnteredProvider.notifier).state = true;
    setState(() {
      _section = OwnerSection.overview;
      _visited
        ..clear()
        ..add(OwnerSection.overview);
    });
  }

  void _backToCountries() =>
      ref.read(ownerCountryEnteredProvider.notifier).state = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    ref.invalidate(ownerSnapshotProvider);
    ref.invalidate(ownerDashboardProvider);
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationsProvider);
    ref.invalidate(announcementsProvider);
    ref.invalidate(compoundManagersProvider);
    ref.invalidate(apartmentManagersProvider);
    try {
      await ref.read(ownerDashboardProvider.future);
    } catch (_) {
      // Errors surface inside each section's error state.
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج من لوحة المالك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('خروج', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(ownerCountryEnteredProvider.notifier).state = false;
      await ref.read(sessionControllerProvider).signOut();
    }
  }

  Widget _page(OwnerSection section) {
    if (!_visited.contains(section)) return const SizedBox.shrink();
    switch (section) {
      case OwnerSection.overview:
        return OverviewSection(
          profile: widget.profile,
          onNavigate: _select,
        );
      case OwnerSection.members:
        return const MembersSection();
      case OwnerSection.tenants:
        return const TenantsSection();
      case OwnerSection.managers:
        return const ManagersSection();
      case OwnerSection.accounting:
        return const AccountingSection();
      case OwnerSection.notifications:
        return const NotificationsAdminSection();
      case OwnerSection.requests:
        return OwnerApprovalsScreen(profile: widget.profile);
      case OwnerSection.portfolio:
        return const PortfolioSection();
      case OwnerSection.profile:
        return ProfileScreen(
          profile: widget.profile,
          subtitle: 'مالك العقارات · لوحة الويب',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(ownerCountryEnteredProvider)) {
      return OwnerCountryHub(
        profile: widget.profile,
        onSelected: _openCountry,
        onSignOut: _confirmSignOut,
      );
    }
    final width = MediaQuery.sizeOf(context).width;
    final sidebarWidth = width < 1180 ? 218.0 : 264.0;
    final unread = ref.watch(unreadNotificationsProvider).maybeWhen(
          data: (value) => value,
          orElse: () => 0,
        );
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
    defaultDisplayCountry = country;

    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: PremiumBackground(
        child: SafeArea(
          child: Row(
            children: [
              SizedBox(
                width: sidebarWidth,
                child: _Sidebar(
                  profile: widget.profile,
                  section: _section,
                  unread: unread,
                  pending: pending,
                  country: country,
                  onSelect: _select,
                  onSignOut: _confirmSignOut,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(
                      profile: widget.profile,
                      section: _section,
                      unread: unread,
                      refreshing: _refreshing,
                      country: country,
                      onCountry: (value) =>
                          ref.read(ownerCountryProvider.notifier).state = value,
                      onCountries: _backToCountries,
                      onRefresh: _refresh,
                      onMagic: () => MagicApartmentsDialog.show(context),
                      onNotifications: () =>
                          _select(OwnerSection.notifications),
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: _sections.indexOf(_section),
                        children: _sections.map(_page).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.profile,
    required this.section,
    required this.unread,
    required this.pending,
    required this.country,
    required this.onSelect,
    required this.onSignOut,
  });

  final AppProfile profile;
  final OwnerSection section;
  final int unread;
  final int pending;
  final AppCountry country;
  final ValueChanged<OwnerSection> onSelect;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navy950, AppColors.navy900],
        ),
        border: Border(
          left: BorderSide(color: Colors.white.withValues(alpha: .06)),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
            child: Row(
              children: [
                const BrandLogo(width: 56, padding: 5, radius: 14),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'The City Property',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${country.flag} ${country.name(english: I18n.isEnglish)} · ${country.currencyCode}',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 10,
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                for (final item in OwnerSection.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _SidebarItem(
                      section: item,
                      selected: section == item,
                      badge: switch (item) {
                        OwnerSection.notifications => unread,
                        OwnerSection.requests => pending,
                        _ => 0,
                      },
                      onTap: () => onSelect(item),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .035),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: Colors.white.withValues(alpha: .06)),
              ),
              child: Row(
                children: [
                  AppAvatar(
                    name: profile.displayName,
                    imageUrl: profile.avatarUrl,
                    size: 34,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Text(
                          'مالك العقارات',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 9,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: tr('تسجيل الخروج'),
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout_rounded,
                        size: 18, color: AppColors.danger),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.section,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final OwnerSection section;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.gold : AppColors.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.gold.withValues(alpha: .11)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected
                  ? AppColors.gold.withValues(alpha: .25)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(section.icon, size: 19, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected ? AppColors.textPrimary : color,
                  ),
                ),
              ),
              if (badge > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.gold : AppColors.danger,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: selected ? AppColors.navy900 : Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.profile,
    required this.section,
    required this.unread,
    required this.refreshing,
    required this.country,
    required this.onCountry,
    required this.onCountries,
    required this.onRefresh,
    required this.onMagic,
    required this.onNotifications,
  });

  final AppProfile profile;
  final OwnerSection section;
  final int unread;
  final bool refreshing;
  final AppCountry country;
  final ValueChanged<AppCountry> onCountry;
  final VoidCallback onCountries;
  final VoidCallback onRefresh;
  final VoidCallback onMagic;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEEE d MMMM yyyy', 'ar').format(DateTime.now());
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.navy900.withValues(alpha: .55),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: .06)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: tr('الدول'),
            onPressed: onCountries,
            icon: const Icon(Icons.grid_view_rounded,
                size: 19, color: AppColors.gold),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(section.icon, size: 15, color: AppColors.gold),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        section.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$date · ${section.subtitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          PopupMenuButton<AppCountry>(
            tooltip: tr('الدولة والعملة'),
            initialValue: country,
            onSelected: onCountry,
            itemBuilder: (context) => AppCountry.values
                .map((item) => PopupMenuItem<AppCountry>(
                      value: item,
                      child: Row(
                        children: [
                          Text(item.flag),
                          const SizedBox(width: 8),
                          Text(
                            '${item.name(english: I18n.isEnglish)} · ${item.currencyCode}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ))
                .toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .04),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: Colors.white.withValues(alpha: .10)),
              ),
              child: Row(
                children: [
                  Text(country.flag, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 6),
                  Text(
                    '${country.name(english: I18n.isEnglish)} · ${country.currencyCode}',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down_rounded,
                      size: 18, color: AppColors.gold),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          const LanguageToggle(compact: true),
          const SizedBox(width: 4),
          _MagicButton(onTap: onMagic),
          const SizedBox(width: 8),
          if (refreshing)
            const Padding(
              padding: EdgeInsetsDirectional.only(end: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.gold,
                ),
              ),
            ),
          IconButton(
            tooltip: tr('تحديث البيانات'),
            onPressed: refreshing ? null : onRefresh,
            icon: const Icon(Icons.refresh_rounded,
                size: 20, color: AppColors.textSecondary),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: tr('الإشعارات'),
                onPressed: onNotifications,
                icon: const Icon(Icons.notifications_none_rounded,
                    size: 21, color: AppColors.textSecondary),
              ),
              if (unread > 0)
                PositionedDirectional(
                  top: 4,
                  start: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: AppColors.navy900, width: 1.5),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .03),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: Colors.white.withValues(alpha: .07)),
            ),
            child: Row(
              children: [
                AppAvatar(
                  name: profile.displayName,
                  imageUrl: profile.avatarUrl,
                  size: 28,
                ),
                const SizedBox(width: 7),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(
                    profile.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MagicButton extends StatelessWidget {
  const _MagicButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 1100;
    final button = compact
        ? IconButton.filled(
            tooltip: tr('الزر السحري'),
            onPressed: onTap,
            icon: const Icon(Icons.auto_awesome_rounded, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.navy900,
              minimumSize: const Size(42, 42),
              elevation: 8,
              shadowColor: AppColors.gold.withValues(alpha: .45),
            ),
          )
        : FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.auto_awesome_rounded, size: 17),
            label: const Text('الزر السحري'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.navy900,
              elevation: 9,
              shadowColor: AppColors.gold.withValues(alpha: .55),
              padding: const EdgeInsets.symmetric(
                  horizontal: 15, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              textStyle: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
    return Tooltip(
      message: 'كل الشقق: المؤجرة والفارغة · العمارة والمستأجر · المتبقي من الإيجار',
      child: button,
    );
  }
}
