import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:the_city_property/core/theme/app_colors.dart';
import 'package:the_city_property/core/theme/app_spacing.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? glowColor;
  final Color? borderColor;
  final Gradient? gradient;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.radius = AppRadius.lg,
    this.glowColor,
    this.borderColor,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: AppColors.glassFill,
            border: Border.all(color: borderColor ?? AppColors.glassStroke),
            gradient: gradient ?? AppColors.cardGradient,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius),
              splashColor: AppColors.gold.withValues(alpha: .08),
              highlightColor: Colors.transparent,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: glowColor == null
            ? AppShadows.soft
            : [
                BoxShadow(
                  color: glowColor!.withValues(alpha: .20),
                  blurRadius: 28,
                  spreadRadius: -6,
                ),
              ],
      ),
      child: content,
    );
  }
}
