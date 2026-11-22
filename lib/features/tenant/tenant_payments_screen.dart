import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/i18n/app_country.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/contact.dart';
import '../../core/utils/system_insets.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';

class TenantPaymentsScreen extends ConsumerWidget {
  const TenantPaymentsScreen({
    super.key,
    required this.profile,
    required this.snapshot,
  });

  final AppProfile profile;
  final TenantSnapshot snapshot;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(tenantSnapshotProvider);
    await ref.read(tenantSnapshotProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lease = snapshot.lease;
    final country = snapshot.apartment?.country ?? AppCountry.iq;
    final totalPaid = snapshot.payments.fold<double>(0, (sum, payment) => sum + payment.amount);
    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => _refresh(ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المدفوعات',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'سجل إيجارك وحالة السداد',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _refresh(ref),
                icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (lease != null)
            RentCountdownCard(
              lease: lease,
              paidThisMonth: snapshot.paidThisMonth,
              country: country,
              onPay: () => _showPaymentInfo(context),
            )
          else
            const GlassCard(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'لا يوجد عقد إيجار نشط حالياً.',
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: _PaymentMetric(
                    label: 'مدفوع هذا الشهر',
                    value: formatMoney(snapshot.paidThisMonth,
                        compact: true, country: country),
                    color: AppColors.occupied,
                    icon: Icons.check_circle_rounded,
                  ),
                ),
                Expanded(
                  child: _PaymentMetric(
                    label: 'إجمالي المدفوعات',
                    value: formatMoney(totalPaid,
                        compact: true, country: country),
                    color: AppColors.gold,
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                ),
                Expanded(
                  child: _PaymentMetric(
                    label: 'عدد الدفعات',
                    value: '${snapshot.payments.length}',
                    color: AppColors.info,
                    icon: Icons.receipt_rounded,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'طرق الدفع', subtitle: 'التسديد عبر مدير العقارات'),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.info_outline_rounded, color: AppColors.gold, size: 21),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const Expanded(
                      child: Text(
                        'سلّم الإيجار نقداً أو عبر التحويل البنكي وسيقوم المدير بتسجيل الدفعة وتزويدك برقم الوصل. يمكنك متابعة كل دفعة هنا فوراً.',
                        style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, height: 1.6, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                if (snapshot.manager != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  contactActions(
                    context: context,
                    phone: snapshot.manager!.phoneNumber,
                    message: 'مرحباً، أرغب بتسديد إيجار ${snapshot.apartment?.label ?? ''}',
                    color: AppColors.occupied,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            title: 'سجل الدفعات',
            subtitle: '${snapshot.payments.length} دفعة',
          ),
          const SizedBox(height: AppSpacing.md),
          if (snapshot.payments.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'لا توجد دفعات بعد',
              message: 'ستظهر هنا كل دفعة يسجلها المدير باسمك.',
            )
          else
            ...snapshot.payments.map(
              (payment) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.occupied.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.check_rounded, color: AppColors.occupied, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatMoney(payment.amount,
                                  withCurrency: true, country: country),
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${formatDate(payment.paymentDate)} · ${payment.methodLabel}'
                              '${payment.receiptNumber == null ? '' : ' · وصل ${payment.receiptNumber}'}',
                              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const StatusPill(label: 'مسددة', color: AppColors.occupied, compact: true),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPaymentInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.navy800,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        padding: withSystemBottomInset(context, const EdgeInsets.all(AppSpacing.lg)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.payments_rounded, color: AppColors.gold),
                SizedBox(width: AppSpacing.sm),
                Text(
                  'تسديد الإيجار',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'تواصل مع مدير العقارات لتسليم مبلغ الإيجار. بعد استلامه سيسجّل الدفعة في النظام وتظهر مباشرة في سجل مدفوعاتك مع رقم الوصل.',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, height: 1.7, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (snapshot.manager != null)
              contactActions(
                context: context,
                phone: snapshot.manager!.phoneNumber,
                message: 'مرحباً، أرغب بتسديد إيجار ${snapshot.apartment?.label ?? ''}',
                color: AppColors.occupied,
              ),
            const SizedBox(height: AppSpacing.sm),
            SoftButton(
              label: 'إغلاق',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMetric extends StatelessWidget {
  const _PaymentMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.w800, color: color),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 8, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
