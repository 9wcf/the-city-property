import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const navy950 = Color(0xFF030A14);
  static const navy900 = Color(0xFF050E1C);
  static const navy850 = Color(0xFF071426);
  static const navy800 = Color(0xFF0A192F);
  static const navy700 = Color(0xFF112240);
  static const navy600 = Color(0xFF1B2F52);
  static const navy500 = Color(0xFF243B63);

  static const gold = Color(0xFFC5A059);
  static const goldLight = Color(0xFFE8D3A3);
  static const goldDark = Color(0xFF9C7B3C);

  static const textPrimary = Color(0xFFF4F7FB);
  static const textSecondary = Color(0xFFA8B8CE);
  static const textMuted = Color(0xFF64748B);

  static const occupied = Color(0xFF2ECC8F);
  static const vacant = Color(0xFFE5484D);
  static const pending = Color(0xFFF5A524);
  static const reserved = Color(0xFF7C5CFF);
  static const overdue = Color(0xFFFF5C5C);
  static const info = Color(0xFF3B9EFF);
  static const success = Color(0xFF2ECC8F);
  static const danger = Color(0xFFE5484D);

  static const glassFill = Color(0x14FFFFFF);
  static const glassStroke = Color(0x24FFFFFF);

  static const brandPurple = Color(0xFF381451);
  static const brandViolet = Color(0xFF5B2E86);
  static const brandLavender = Color(0xFFA37FB1);
  static const brandInk = Color(0xFF262324);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandViolet, brandPurple],
  );

  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldLight, gold, goldDark],
  );

  static const bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [navy800, navy900],
  );

  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x1FFFFFFF), Color(0x08FFFFFF)],
  );

  static const dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF7A7A), danger],
  );
}

Color statusColorFor(String status) {
  switch (status) {
    case 'occupied':
    case 'active':
    case 'approved':
    case 'completed':
      return AppColors.occupied;
    case 'vacant':
    case 'rejected':
    case 'cancelled':
      return AppColors.vacant;
    case 'maintenance':
    case 'pending':
    case 'submitted':
    case 'in_progress':
      return AppColors.pending;
    case 'reserved':
      return AppColors.reserved;
    default:
      return AppColors.textMuted;
  }
}
