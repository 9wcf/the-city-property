import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppSpacing {
  AppSpacing._();
  static const xs = 4.0, sm = 8.0, md = 16.0, lg = 24.0, xl = 32.0, xxl = 48.0;
}

class AppRadius {
  AppRadius._();
  static const sm = 10.0, md = 16.0, lg = 22.0, xl = 28.0, pill = 999.0;
}

class AppShadows {
  AppShadows._();
  static const soft = [
    BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 12)),
  ];
  static List<BoxShadow> goldGlow = [
    BoxShadow(color: AppColors.gold.withValues(alpha: .18), blurRadius: 30, spreadRadius: -6),
  ];
}
