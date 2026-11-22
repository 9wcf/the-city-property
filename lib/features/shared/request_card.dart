import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_utils.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';

class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.request,
    this.onTap,
    this.showTenant = true,
    this.trailing,
  });

  final MaintenanceRequest request;
  final VoidCallback? onTap;
  final bool showTenant;
  final Widget? trailing;

  Color get _color {
    if (request.isCompleted) return AppColors.occupied;
    if (request.isRejected) return AppColors.danger;
    if (request.isInProgress) return AppColors.info;
    return AppColors.pending;
  }

  @override
  Widget build(BuildContext context) {
    final cost = request.finalCost ?? request.estimatedCost;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: request.needsOwnerApproval ? AppColors.gold.withValues(alpha: .35) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _color.withValues(alpha: .25)),
                ),
                child: Icon(
                  maintenanceCategoryIcons[request.category] ?? Icons.handyman_rounded,
                  color: _color,
                  size: 21,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        request.categoryLabel,
                        if (request.apartmentLabel != null) request.apartmentLabel!,
                        if (showTenant && request.tenantName != null) request.tenantName!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              trailing ??
                  StatusPill(
                    label: request.statusLabel,
                    color: _color,
                    icon: request.isCompleted
                        ? Icons.check_circle_rounded
                        : request.isInProgress
                            ? Icons.engineering_rounded
                            : request.isRejected
                                ? Icons.block_rounded
                                : Icons.schedule_rounded,
                    compact: true,
                  ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (cost != null) ...[
                const Icon(Icons.payments_rounded, size: 14, color: AppColors.gold),
                const SizedBox(width: 4),
                Text(
                  formatMoney(cost, withCurrency: true),
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              if (request.priority == 'emergency' || request.priority == 'urgent')
                const StatusPill(label: 'عاجل', color: AppColors.danger, icon: Icons.priority_high_rounded, compact: true),
              const Spacer(),
              Text(
                formatRelative(request.createdAt),
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
          if (request.needsOwnerApproval) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.gold.withValues(alpha: .22)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded, size: 13, color: AppColors.gold),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'بانتظار موافقة المالك على الكلفة',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                  Text(
                    formatRelative(request.updatedAt),
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 9, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class RequestFilterChips extends StatelessWidget {
  const RequestFilterChips({
    super.key,
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  final List<String> filters;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final active = filter == selected;
          return GestureDetector(
            onTap: () => onSelected(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active ? AppColors.gold : Colors.white.withValues(alpha: .04),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: active ? AppColors.gold : Colors.white.withValues(alpha: .08),
                ),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: active ? AppColors.navy900 : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
