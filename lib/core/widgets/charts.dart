import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:the_city_property/core/i18n/app_country.dart';
import 'package:the_city_property/core/theme/app_colors.dart';
import 'package:the_city_property/core/theme/app_spacing.dart';
import 'package:the_city_property/core/utils/app_utils.dart';
import 'package:the_city_property/data/models.dart';

import 'glass_card.dart';
import 'premium_widgets.dart';

class OccupancyRing extends StatelessWidget {
  const OccupancyRing({
    super.key,
    required this.rate,
    this.size = 112,
    this.color = AppColors.gold,
    this.label,
    this.sublabel,
  });

  final double rate;
  final double size;
  final Color color;
  final String? label;
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: rate.clamp(0, 1)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _RingPainter(value: value, color: color),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    percent(value),
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: size * .22,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  if (label != null)
                    Text(
                      label!,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: size * .095,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (sublabel != null)
                    Text(
                      sublabel!,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: size * .08,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - 12) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..color = Colors.white.withValues(alpha: .07);
    canvas.drawCircle(center, radius, bg);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: .10);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, glow);

    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: .45), color],
        stops: const [0, 1],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}

class OccupancyBar extends StatelessWidget {
  const OccupancyBar({
    super.key,
    required this.rate,
    this.color = AppColors.gold,
    this.height = 8,
    this.showLabel = true,
    this.label,
  });

  final double rate;
  final Color color;
  final double height;
  final bool showLabel;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Text(
                  label ?? 'نسبة الإشغال',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                Text(
                  percent(rate),
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: Stack(
            children: [
              Container(
                height: height,
                color: Colors.white.withValues(alpha: .07),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: rate.clamp(0, 1)),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => FractionallySizedBox(
                  widthFactor: value,
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: .55), color],
                      ),
                      borderRadius: BorderRadius.circular(height),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MiniBars extends StatelessWidget {
  const MiniBars({
    super.key,
    required this.values,
    required this.labels,
    this.height = 92,
    this.color = AppColors.gold,
  });

  final List<double> values;
  final List<String> labels;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.isEmpty ? 0.0 : values.reduce(math.max);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (index) {
          final value = values[index];
          final factor = maxValue == 0 ? 0.04 : (value / maxValue).clamp(0.04, 1).toDouble();
          final isLast = index == values.length - 1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: factor),
                        duration: Duration(milliseconds: 500 + index * 90),
                        curve: Curves.easeOutCubic,
                        builder: (context, animated, _) => FractionallySizedBox(
                          heightFactor: animated,
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: isLast
                                    ? [color.withValues(alpha: .6), color]
                                    : [Colors.white.withValues(alpha: .08), Colors.white.withValues(alpha: .22)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    index < labels.length ? labels[index] : '',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 9,
                      color: isLast ? color : AppColors.textMuted,
                      fontWeight: isLast ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class RentCountdownCard extends StatelessWidget {
  const RentCountdownCard({
    super.key,
    required this.lease,
    required this.paidThisMonth,
    this.onPay,
    this.onDetails,
    this.country = AppCountry.iq,
  });

  final Lease lease;
  final double paidThisMonth;
  final VoidCallback? onPay;
  final VoidCallback? onDetails;
  final AppCountry country;

  @override
  Widget build(BuildContext context) {
    final due = nextDueDate(lease);
    final left = daysUntil(due);
    final paid = paidThisMonth >= lease.monthlyRent && lease.monthlyRent > 0;
    final color = paid
        ? AppColors.occupied
        : left < 0
            ? AppColors.danger
            : left <= 7
                ? AppColors.pending
                : AppColors.gold;
    final progress = paid ? 1.0 : (left.clamp(0, 30) / 30).toDouble();

    return GlassCard(
      glowColor: color,
      borderColor: color.withValues(alpha: .28),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: color.withValues(alpha: .30)),
                ),
                child: Icon(
                  paid ? Icons.verified_rounded : Icons.calendar_month_rounded,
                  color: color,
                  size: 23,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paid ? 'تم تسديد إيجار هذا الشهر' : formatDaysLeft(left),
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      paid ? 'شكراً لالتزامك بالدفع في الوقت المحدد' : 'تاريخ الاستحقاق ${formatDate(due)}',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (paid)
                const StatusPill(label: 'مسدد', color: AppColors.occupied, icon: Icons.check_rounded, compact: true),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الإيجار الشهري',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        formatMoney(lease.monthlyRent,
                            withCurrency: true, country: country),
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (onDetails != null)
                TextButton(onPressed: onDetails, child: const Text('تفاصيل العقد')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(height: 10, color: Colors.white.withValues(alpha: .07)),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress.clamp(0, 1)),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(colors: [color.withValues(alpha: .55), color]),
                        boxShadow: [
                          BoxShadow(color: color.withValues(alpha: .35), blurRadius: 10, spreadRadius: -2),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                paid ? 'متبقي 0 يوم' : (left < 0 ? 'تأخير ${-left} يوم' : 'متبقي $left يوم'),
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (!paid)
                Text(
                  'المدفوع هذا الشهر ${formatMoney(paidThisMonth, compact: true, country: country)}',
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
                ),
            ],
          ),
          if (!paid && onPay != null) ...[
            const SizedBox(height: AppSpacing.md),
            GoldButton(label: 'تسديد الإيجار الآن', icon: Icons.payments_rounded, onPressed: onPay, height: 48),
          ],
        ],
      ),
    );
  }
}

class ApartmentStatusChip extends StatelessWidget {
  const ApartmentStatusChip({
    super.key,
    required this.apartment,
    this.onTap,
    this.showRent = false,
  });

  final Apartment apartment;
  final VoidCallback? onTap;
  final bool showRent;

  @override
  Widget build(BuildContext context) {
    final color = switch (apartment.status) {
      ApartmentStatus.occupied => AppColors.occupied,
      ApartmentStatus.vacant => AppColors.vacant,
      ApartmentStatus.maintenance => AppColors.pending,
      ApartmentStatus.reserved => AppColors.reserved,
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: color.withValues(alpha: .35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(apartment.status.icon, size: 12, color: color),
                  const SizedBox(width: 4),
                  Text(
                    apartment.displayName,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
              if (showRent) ...[
                const SizedBox(height: 2),
                Text(
                  formatMoney(apartment.rentAmount,
                      compact: true, country: apartment.country),
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 9,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ApartmentListTile extends StatelessWidget {
  const ApartmentListTile({
    super.key,
    required this.apartment,
    this.tenantName,
    this.onTap,
    this.trailing,
  });

  final Apartment apartment;
  final String? tenantName;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = switch (apartment.status) {
      ApartmentStatus.occupied => AppColors.occupied,
      ApartmentStatus.vacant => AppColors.vacant,
      ApartmentStatus.maintenance => AppColors.pending,
      ApartmentStatus.reserved => AppColors.reserved,
    };
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: .25)),
            ),
            child: Icon(apartment.status.icon, color: color, size: 21),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      apartment.displayName,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusPill(label: apartment.status.label, color: color, compact: true),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (apartment.buildingName != null) apartment.buildingName!,
                    if (apartment.floorLabel.isNotEmpty) apartment.floorLabel,
                    if (apartment.roomCount > 0) '${apartment.roomCount} غرف',
                    if (apartment.areaSqm != null) '${apartment.areaSqm!.round()} م²',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textMuted),
                ),
                if (tenantName != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'المستأجر: $tenantName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(apartment.rentAmount,
                    compact: true, country: apartment.country),
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'شهرياً',
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 9, color: AppColors.textMuted),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ],
      ),
    );
  }
}
