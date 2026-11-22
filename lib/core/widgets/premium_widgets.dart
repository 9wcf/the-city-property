import 'dart:convert';

import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:the_city_property/core/theme/app_colors.dart';
import 'package:the_city_property/core/theme/app_spacing.dart';

import 'glass_card.dart';

class PremiumBackground extends StatelessWidget {
  const PremiumBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.bgGradient),
          ),
        ),
        Positioned(
          top: -180,
          right: -120,
          child: Container(
            width: 380,
            height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.gold.withValues(alpha: .18),
                  AppColors.gold.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -200,
          left: -140,
          child: Container(
            width: 420,
            height: 420,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.info.withValues(alpha: .10),
                  AppColors.info.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class PremiumScaffold extends StatelessWidget {
  const PremiumScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.showBack = true,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.padding = const EdgeInsets.fromLTRB(
        AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
    this.safeBottom = true,
  });

  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final bool showBack;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final EdgeInsets padding;
  final bool safeBottom;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: AppColors.navy900,
      resizeToAvoidBottomInset: true,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: PremiumBackground(
        child: SafeArea(
          bottom: safeBottom,
          child: Column(
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                  child: Row(
                    children: [
                      if (showBack && canPop)
                        _RoundIconButton(
                          icon: Icons.arrow_forward_rounded,
                          onTap: () => Navigator.of(context).pop(),
                        )
                      else
                        const SizedBox(width: 4),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          title!,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      ...?actions,
                    ],
                  ),
                ),
              if (title != null) const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: Padding(padding: padding, child: body),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}

class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final button = Opacity(
      opacity: enabled ? 1 : .55,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: AppColors.goldGradient,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: enabled ? AppShadows.goldGlow : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: AppColors.navy900),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 20, color: AppColors.navy900),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy900,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color = AppColors.gold,
    this.expand = true,
    this.height = 50,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: color.withValues(alpha: .45)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.compact = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        vertical: compact ? 4 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 12 : 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Tajawal',
              color: color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class PremiumHeader extends StatelessWidget {
  const PremiumHeader({
    super.key,
    required this.name,
    required this.roleLabel,
    this.greeting,
    this.avatarUrl,
    this.subtitle,
    this.actions,
  });

  final String name;
  final String roleLabel;
  final String? greeting;
  final String? avatarUrl;
  final String? subtitle;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppAvatar(name: name, imageUrl: avatarUrl, size: 50, showRing: true),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting ?? greetingText(),
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        ...?actions,
        if (actions == null)
          StatusPill(
              label: roleLabel,
              color: AppColors.gold,
              icon: Icons.verified_rounded,
              compact: true),
      ],
    );
  }

  String greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير';
    if (hour < 17) return 'مساء الخير';
    return 'مساء الخير';
  }
}

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 44,
    this.showRing = false,
  });

  final String name;
  final String? imageUrl;
  final double size;
  final bool showRing;

  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '؟';
    if (parts.length == 1) return parts.first.substring(0, 1);
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}';
  }

  @override
  Widget build(BuildContext context) {
    final avatar = ClipOval(
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? Image.network(
              imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initialAvatar(),
            )
          : _initialAvatar(),
    );
    if (!showRing) return avatar;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.goldGradient,
      ),
      child: avatar,
    );
  }

  Widget _initialAvatar() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.gold.withValues(alpha: .9), AppColors.goldDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontWeight: FontWeight.w800,
          fontSize: size * .34,
          color: AppColors.navy900,
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.caption,
    this.onTap,
    this.compact = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      glowColor: color,
      padding: EdgeInsets.all(compact ? AppSpacing.sm + 2 : AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(compact ? 7 : 9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: compact ? 16 : 19),
              ),
              const Spacer(),
              if (caption != null)
                Flexible(
                  child: Text(
                    caption!,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w800,
              fontSize: compact ? 20 : 24,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: .08),
                border:
                    Border.all(color: AppColors.gold.withValues(alpha: .20)),
              ),
              child: Icon(icon, color: AppColors.gold, size: 34),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13,
                  height: 1.6,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.lg),
              SoftButton(
                  label: actionLabel!, onPressed: onAction, expand: false),
            ],
          ],
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color = AppColors.gold,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing ??
              const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 14, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navy900,
        border:
            Border(top: BorderSide(color: Colors.white.withValues(alpha: .06))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final selected = index == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.gold.withValues(alpha: .12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              selected
                                  ? item.activeIcon ?? item.icon
                                  : item.icon,
                              size: 22,
                              color: selected
                                  ? AppColors.gold
                                  : AppColors.textMuted,
                            ),
                            if (item.badge != null && item.badge! > 0)
                              Positioned(
                                top: -6,
                                left: -8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.vacant,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${item.badge}',
                                    style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              item.label,
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 10,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: selected
                                    ? AppColors.gold
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    this.activeIcon,
    this.badge,
  });

  final String label;
  final IconData icon;
  final IconData? activeIcon;
  final int? badge;
}

class TimelineStep extends StatelessWidget {
  const TimelineStep({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.isLast = false,
    this.isActive = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isLast;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: isActive ? .18 : .06),
                  border: Border.all(
                      color: color.withValues(alpha: isActive ? .6 : .2)),
                ),
                child: Icon(icon,
                    size: 16, color: isActive ? color : AppColors.textMuted),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: color.withValues(alpha: isActive ? .25 : .10),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: isActive
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                      height: 1.5,
                      color: AppColors.textMuted,
                    ),
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

class PhotoGrid extends StatelessWidget {
  const PhotoGrid({super.key, required this.urls, this.height = 92});

  final List<String> urls;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final url = urls[index];
          return GestureDetector(
            onTap: () => showDialog(
              context: context,
              builder: (_) => Dialog(
                backgroundColor: Colors.transparent,
                child: InteractiveViewer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.network(
                url,
                width: height * 1.3,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: height * 1.3,
                  color: AppColors.navy700,
                  child: const Icon(Icons.broken_image_rounded,
                      color: AppColors.textMuted),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ShimmerBox extends StatefulWidget {
  const ShimmerBox({super.key, this.height = 16, this.width, this.radius = 8});

  final double height;
  final double? width;
  final double radius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final value = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + value * 2, 0),
              end: Alignment(1 + value * 2, 0),
              colors: const [
                Color(0x11FFFFFF),
                Color(0x28FFFFFF),
                Color(0x11FFFFFF),
              ],
            ),
          ),
        );
      },
    );
  }
}

class LoadingList extends StatelessWidget {
  const LoadingList({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, __) => const GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(height: 14, width: 130),
            SizedBox(height: 10),
            ShimmerBox(height: 10, width: 200),
            SizedBox(height: 6),
            ShimmerBox(height: 10, width: 90),
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 54, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              SoftButton(
                  label: 'إعادة المحاولة',
                  onPressed: onRetry,
                  expand: false,
                  icon: Icons.refresh_rounded),
            ],
          ],
        ),
      ),
    );
  }
}

void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(fontFamily: 'Tajawal')),
      backgroundColor: AppColors.navy700,
      duration: const Duration(seconds: 3),
    ),
  );
}

void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(fontFamily: 'Tajawal')),
      backgroundColor: AppColors.danger,
      duration: const Duration(seconds: 4),
    ),
  );
}

// بعض رسائل قاعدة البيانات تصل بايتاتها UTF-8 مفكوكة خطأ كـ Windows-1256
// فتظهر رموزاً غير مقروءة؛ نعيد تركيب البايتات ثم نفكها من جديد.
const _cp1256High =
    '\u20AC\u067E\u201A\u0192\u201E\u2026\u2020\u2021\u02C6\u2030\u0679\u2039\u0152\u0686\u0698\u0688'
    '\u06AF\u2018\u2019\u201C\u201D\u2022\u2013\u2014\u06A9\u2122\u0691\u203A\u0153\u200C\u200D\u06BA'
    '\u00A0\u060C\u00A2\u00A3\u00A4\u00A5\u00A6\u00A7\u00A8\u00A9\u06BE\u00AB\u00AC\u00AD\u00AE\u00AF'
    '\u00B0\u00B1\u00B2\u00B3\u00B4\u00B5\u00B6\u00B7\u00B8\u00B9\u061B\u00BB\u00BC\u00BD\u00BE\u061F'
    '\u06C1\u0621\u0622\u0623\u0624\u0625\u0626\u0627\u0628\u0629\u062A\u062B\u062C\u062D\u062E\u062F'
    '\u0630\u0631\u0632\u0633\u0634\u0635\u0636\u00D7\u0637\u0638\u0639\u063A\u0640\u0641\u0642\u0643'
    '\u00E0\u0644\u00E2\u0645\u0646\u0647\u0648\u00E7\u00E8\u00E9\u00EA\u00EB\u0649\u064A\u00EE\u00EF'
    '\u064B\u064C\u064D\u064E\u00F4\u064F\u0650\u00F7\u0651\u00F9\u0652\u00FB\u00FC\u200E\u200F\u06D2';

final Map<int, int> _cp1256ByteOf = () {
  final map = <int, int>{};
  for (var byte = 0x00; byte < 0x7F; byte++) {
    map[byte] = byte;
  }
  for (var i = 0; i < _cp1256High.length; i++) {
    map.putIfAbsent(_cp1256High.codeUnitAt(i), () => 0x80 + i);
  }
  return map;
}();

bool _looksLikeMojibake(String text) {
  var suspicious = 0;
  for (final rune in text.runes) {
    if (rune == 0x0637 ||
        rune == 0x0638 ||
        (rune >= 0x00A7 && rune <= 0x00B9) ||
        rune == 0x0192 ||
        rune == 0x2026 ||
        rune == 0x201A ||
        rune == 0x201E ||
        rune == 0x2039 ||
        rune == 0x203A) {
      suspicious++;
    }
  }
  return suspicious >= 4;
}

String? _decodeCp1256Mojibake(String text) {
  final bytes = <int>[];
  for (final rune in text.runes) {
    final byte = _cp1256ByteOf[rune];
    if (byte == null) return null;
    bytes.add(byte);
  }
  final String decoded;
  try {
    decoded = utf8.decode(bytes);
  } on FormatException {
    return null;
  }
  var arabic = 0;
  for (final rune in decoded.runes) {
    if (rune >= 0x0621 && rune <= 0x064A) arabic++;
  }
  return arabic >= 3 ? decoded : null;
}

String _repairBrokenArabic(String text) {
  var current = text;
  for (var pass = 0; pass < 2 && _looksLikeMojibake(current); pass++) {
    final repaired = _decodeCp1256Mojibake(current);
    if (repaired == null) break;
    current = repaired;
  }
  return current;
}

String friendlyError(Object error) {
  final text = _repairBrokenArabic(error.toString());
  if (text.contains('relation') && text.contains('does not exist')) {
    return 'هذه الخدمة غير مهيأة في قاعدة البيانات بعد. شغّل ملف supabase/schema.sql.';
  }
  if (text.contains('invalid input value for enum') ||
      (text.contains('column') && text.contains('does not exist'))) {
    return 'قاعدة البيانات تحتاج تحديثاً بسيطاً. شغّل ملف supabase/schema.sql ثم أعد المحاولة.';
  }
  if (text.contains('manager_add_tenant') &&
      (text.contains('does not exist') ||
          text.contains('schema cache') ||
          text.contains('Could not find the function'))) {
    return 'خدمة إضافة المستأجر غير مفعّلة بعد. شغّل ملف supabase/schema.sql في SQL Editor ثم أعد المحاولة.';
  }
  if (text.contains('profiles_id_fkey')) {
    return 'تعذر إنشاء حساب المستأجر. حدّث قاعدة البيانات بملف supabase/schema.sql ثم أعد المحاولة.';
  }
  if (text.contains('permission denied for schema auth') ||
      text.contains('permission denied for table users')) {
    return 'دالة إضافة المستأجر لا تملك صلاحية إنشاء حساب الدخول. شغّل supabase/schema.sql من حساب مالك المشروع.';
  }
  if (text.contains('Invalid login credentials')) {
    return 'بيانات الدخول غير صحيحة.';
  }
  if (text.contains('Unable to get SMS provider') ||
      text.contains('Error sending sms') ||
      text.contains('sms provider')) {
    return 'تعذر إرسال رمز التحقق. تحقق من إعدادات مزود الرسائل (OTPIQ) ورصيده ثم أعد المحاولة.';
  }
  if (text.contains('Phone not confirmed') ||
      text.contains('phone_not_confirmed')) {
    return 'رقم الهاتف غير مؤكد. أكمل خطوة رمز التحقق أولاً.';
  }
  if (text.contains('already registered') ||
      text.contains('already been registered') ||
      text.contains('phone_exists') ||
      text.contains('User already exists')) {
    return 'هذا الرقم مسجل مسبقاً. سجّل الدخول بكلمة المرور بدلاً من إنشاء حساب جديد.';
  }
  if (text.contains('Token has expired') ||
      text.contains('otp_expired') ||
      text.contains('Invalid OTP') ||
      text.contains('invalid_otp')) {
    return 'رمز التحقق غير صحيح أو منتهي الصلاحية. اطلب رمزاً جديداً.';
  }
  if (text.contains('Password should be at least') ||
      text.contains('weak_password')) {
    return 'كلمة المرور ضعيفة. استخدم 8 أحرف على الأقل.';
  }
  if (text.contains('Signups not allowed') ||
      text.contains('signup_disabled')) {
    return 'التسجيل غير مسموح حالياً في إعدادات المشروع.';
  }
  if (text.contains('phone provider') || text.contains('Phone provider')) {
    return 'تسجيل الدخول بالهاتف غير مفعّل. فعّل Phone provider في إعدادات Supabase ثم أعد المحاولة.';
  }
  if (text.contains('rate limit')) {
    return 'محاولات كثيرة. انتظر قليلاً ثم أعد المحاولة.';
  }
  if (text.contains('JWT') ||
      text.contains('permission denied') ||
      text.contains('row-level security')) {
    return 'ليس لديك صلاحية لهذا الإجراء.';
  }
  const arabic = <String, String>{
    'هذا الرقم مسجل': 'هذا الرقم مسجل مسبقاً بحساب آخر (مالك أو مدير أو مستأجر). استخدم رقماً مختلفاً لإضافة المستأجر.',
    'الشقة ليست فارغة': 'هذه الشقة مشغولة بمستأجر حالياً. اختر شقة فارغة أو أنهِ العقد الحالي أولاً.',
    'يوجد عقد نشط': 'يوجد عقد نشط على هذه الشقة. أنهِ العقد الحالي قبل إضافة مستأجر جديد.',
    'هذا المستأجر لديه عقد نشط': 'هذا المستأجر مرتبط بعقد نشط في شقة أخرى.',
    'ليس لديك صلاحية على هذه الشقة': 'ليس لديك صلاحية على هذه الشقة.',
    'تاريخ العقد غير صالح': 'تاريخ العقد غير صالح. تحقق من تاريخ البداية ومدة العقد.',
    'اسم المستأجر مطلوب': 'اسم المستأجر مطلوب.',
    'رقم الهاتف غير صالح': 'رقم الهاتف غير صالح.',
    'كلمة المرور يجب أن تكون': 'كلمة المرور يجب أن تكون 8 أحرف على الأقل.',
    'مبلغ الإيجار غير صالح': 'مبلغ الإيجار غير صالح.',
    'الشقة غير موجودة': 'الشقة غير موجودة. أعد تحميل الصفحة ثم اختر الشقة من جديد.',
    'ليس لديك صلاحية لإضافة المستأجرين': 'ليس لديك صلاحية لإضافة المستأجرين.',
    'يجب تسجيل الدخول أولاً': 'انتهت الجلسة. سجّل الدخول من جديد.',
    'row-level security': 'ليس لديك صلاحية لهذا الإجراء على البناية أو المجمع المحدد.',
  };
  for (final entry in arabic.entries) {
    if (text.contains(entry.key)) return entry.value;
  }
  final postgrest = RegExp(
    r'PostgrestException\(\s*message:\s*(.*?)(?:,\s*(?:code|details|hint):|\)\s*$)',
    dotAll: true,
  ).firstMatch(text);
  final message = (postgrest?.group(1) ?? text)
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceFirst(RegExp(r'^PostgrestException\(\s*message:\s*'), '')
      .trim();
  if (message.isEmpty ||
      message.length > 200 ||
      message.contains('PostgrestException') ||
      _looksLikeMojibake(message)) {
    return 'تعذر تنفيذ العملية. تحقق من البيانات المدخلة وأعد المحاولة.';
  }
  return message;
}
