import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// شعار The City inside an optional frosted-glass card.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.width = 96,
    this.glass = true,
    this.padding = 10,
    this.radius,
    this.shadow = true,
    this.shimmer,
  });

  static const asset = 'assets/images/logo.png';
  static const aspectRatio = 611 / 403;

  final double width;
  final bool glass;
  final double padding;
  final double? radius;
  final bool shadow;

  /// 0..1 sweep position for a moving light band over the emblem.
  final double? shimmer;

  double get height => width / aspectRatio;

  @override
  Widget build(BuildContext context) {
    Widget logo = Image.asset(
      asset,
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    final sweep = shimmer;
    if (sweep != null) {
      logo = ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment(-1.8 + 3.6 * sweep, -1),
          end: Alignment(-0.8 + 3.6 * sweep, 1),
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: .55),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0.42, 0.5, 0.58],
        ).createShader(bounds),
        child: logo,
      );
    }

    if (!glass) return logo;

    final corner = radius ?? (width * .22);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(corner),
        boxShadow: [
          if (shadow)
            BoxShadow(
              color: AppColors.brandViolet.withValues(alpha: .38),
              blurRadius: width * .35,
              spreadRadius: -width * .08,
              offset: Offset(0, width * .08),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(corner),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(corner),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x1FFFFFFF), Color(0x08FFFFFF)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: .16)),
            ),
            child: logo,
          ),
        ),
      ),
    );
  }
}
