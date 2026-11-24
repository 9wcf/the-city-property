import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/app_country.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_utils.dart';

enum OwnerSection {
  overview,
  members,
  tenants,
  managers,
  accounting,
  notifications,
  requests,
  portfolio,
  profile,
}

extension OwnerSectionX on OwnerSection {
  String get label => switch (this) {
        OwnerSection.overview => 'نظرة عامة',
        OwnerSection.members => 'الأعضاء',
        OwnerSection.tenants => 'المستأجرون',
        OwnerSection.managers => 'المديرون',
        OwnerSection.accounting => 'المحاسبة',
        OwnerSection.notifications => 'الإشعارات',
        OwnerSection.requests => 'الطلبات والموافقات',
        OwnerSection.portfolio => 'العقارات',
        OwnerSection.profile => 'حسابي',
      };

  String get subtitle => switch (this) {
        OwnerSection.overview => 'ملخص أداء المحفظة والتحصيل',
        OwnerSection.members => 'إدارة المستأجرين والمديرين وصلاحياتهم',
        OwnerSection.tenants => 'المستأجرون الحاليون وأرشيف المستأجرين',
        OwnerSection.managers => 'تعيين المديرين للعقارات والشقق',
        OwnerSection.accounting => 'الفواتير، الدفعات، المصروفات والأرباح',
        OwnerSection.notifications => 'رسائل وإشعارات للمستأجرين والمديرين',
        OwnerSection.requests => 'متابعة بلاغات الصيانة والموافقات',
        OwnerSection.portfolio => 'العقارات والعمارات والشقق',
        OwnerSection.profile => 'بيانات حسابك وأمان الدخول',
      };

  IconData get icon => switch (this) {
        OwnerSection.overview => Icons.space_dashboard_rounded,
        OwnerSection.members => Icons.groups_rounded,
        OwnerSection.tenants => Icons.people_alt_rounded,
        OwnerSection.managers => Icons.support_agent_rounded,
        OwnerSection.accounting => Icons.account_balance_wallet_rounded,
        OwnerSection.notifications => Icons.campaign_rounded,
        OwnerSection.requests => Icons.fact_check_rounded,
        OwnerSection.portfolio => Icons.domain_rounded,
        OwnerSection.profile => Icons.person_rounded,
      };
}

class WebPanel extends StatelessWidget {
  const WebPanel({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.action,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.glowColor,
    this.borderColor,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? action;
  final EdgeInsets padding;
  final Color? glowColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: AppColors.navy850.withValues(alpha: .82),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: .07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final heading = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title!,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 16,
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
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                );
                if (action == null) return heading;
                if (constraints.maxWidth < 480) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      heading,
                      const SizedBox(height: AppSpacing.sm),
                      action!,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: heading),
                    action!,
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          child,
        ],
      ),
    );
    if (glowColor == null) return content;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: glowColor!.withValues(alpha: .16),
            blurRadius: 28,
            spreadRadius: -8,
          ),
        ],
      ),
      child: content,
    );
  }
}

class WebPageHeader extends StatelessWidget {
  const WebPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: constraints.maxWidth < 600 ? 21 : 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
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
        );
        if (actions.isEmpty) return heading;
        final actionsWrap =
            Wrap(spacing: 10, runSpacing: 10, children: actions);
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              const SizedBox(height: AppSpacing.sm),
              actionsWrap,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: heading),
            const SizedBox(width: AppSpacing.md),
            actionsWrap,
          ],
        );
      },
    );
  }
}

class WebKpiCard extends StatelessWidget {
  const WebKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.caption,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: AppColors.navy850.withValues(alpha: .85),
            border: Border.all(color: color.withValues(alpha: .22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 18),
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
              const SizedBox(height: AppSpacing.sm),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
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
        ),
      ),
    );
  }
}

class WebKpiGrid extends StatelessWidget {
  const WebKpiGrid({
    super.key,
    required this.children,
    this.minWidth = 200,
  });

  final List<Widget> children;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveMin = constraints.maxWidth < 520 ? 148.0 : minWidth;
        final columns =
            (constraints.maxWidth / effectiveMin).floor().clamp(1, 6);
        const gap = 12.0;
        final width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(),
        );
      },
    );
  }
}

class WebColumns extends StatelessWidget {
  const WebColumns({
    super.key,
    required this.first,
    required this.second,
    this.firstFlex = 2,
    this.secondFlex = 1,
    this.breakpoint = 980,
  });

  final Widget first;
  final Widget second;
  final int firstFlex;
  final int secondFlex;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first,
              const SizedBox(height: AppSpacing.md),
              second,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: firstFlex, child: first),
            const SizedBox(width: AppSpacing.md),
            Expanded(flex: secondFlex, child: second),
          ],
        );
      },
    );
  }
}

class WebToolbarChip extends StatelessWidget {
  const WebToolbarChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : Colors.white.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected
                ? AppColors.gold
                : Colors.white.withValues(alpha: .09),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? AppColors.navy900 : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class WebRowAction extends StatelessWidget {
  const WebRowAction({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.color = AppColors.textSecondary,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: .07)),
          ),
          child: Icon(icon,
              size: 17, color: onTap == null ? AppColors.textMuted : color),
        ),
      ),
    );
  }
}

class WebEmpty extends StatelessWidget {
  const WebEmpty({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 34),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class WebTableColumn {
  const WebTableColumn(this.label, {this.flex = 1, this.align = TextAlign.start});

  final String label;
  final int flex;
  final TextAlign align;
}

class WebTable extends StatelessWidget {
  const WebTable({
    super.key,
    required this.columns,
    required this.rows,
    this.empty,
    this.minHeight = 54,
    this.minWidth = 760,
  });

  final List<WebTableColumn> columns;
  final List<List<Widget>> rows;
  final Widget? empty;
  final double minHeight;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return empty ?? const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < minWidth
            ? minWidth
            : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .025),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      for (final column in columns)
                        Expanded(
                          flex: column.flex,
                          child: Text(
                            column.label,
                            textAlign: column.align,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                for (var index = 0; index < rows.length; index++) ...[
                  Container(
                    constraints: BoxConstraints(minHeight: minHeight),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: .05),
                          width: index == rows.length - 1 ? 0 : 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        for (var cell = 0; cell < columns.length; cell++)
                          Expanded(
                            flex: columns[cell].flex,
                            child: Align(
                              alignment: switch (columns[cell].align) {
                                TextAlign.center => Alignment.center,
                                TextAlign.end => Alignment.centerLeft,
                                _ => Alignment.centerRight,
                              },
                              child: cell < rows[index].length
                                  ? rows[index][cell]
                                  : const SizedBox.shrink(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class WebPill extends StatelessWidget {
  const WebPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Tajawal',
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WebInfoTile extends StatelessWidget {
  const WebInfoTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color = AppColors.textPrimary,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String webMonthName(DateTime date) =>
    DateFormat('MMMM yyyy', I18n.isEnglish ? 'en' : 'ar').format(date);

String webShortMonth(DateTime date) =>
    DateFormat('MMM', I18n.isEnglish ? 'en' : 'ar').format(date);

DateTime startOfMonth(DateTime date) => DateTime(date.year, date.month, 1);

DateTime addMonths(DateTime date, int months) =>
    DateTime(date.year, date.month + months, 1);

String moneyText(num value, {bool withCurrency = true, AppCountry? country}) =>
    formatMoney(value, withCurrency: withCurrency, country: country);
