import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_utils.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';

class PendingLeaseCard extends ConsumerStatefulWidget {
  const PendingLeaseCard({
    super.key,
    required this.lease,
    required this.manager,
    this.onChanged,
  });

  final Lease lease;
  final AppProfile manager;
  final VoidCallback? onChanged;

  @override
  ConsumerState<PendingLeaseCard> createState() => _PendingLeaseCardState();
}

class _PendingLeaseCardState extends ConsumerState<PendingLeaseCard> {
  bool _busy = false;

  Future<void> _approve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تفعيل عقد الإيجار'),
        content: Text(
          'سيتم ربط ${widget.lease.tenantName ?? 'المستأجر'} بـ${widget.lease.apartmentLabel ?? 'الشقة'} '
          'وتحويل حالتها إلى مؤجرة. هل تريد المتابعة؟',
          style: const TextStyle(fontFamily: 'Tajawal', height: 1.6),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('تفعيل العقد')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => ref.read(repositoryProvider).approveLease(widget.lease), 'تم تفعيل العقد بنجاح');
  }

  Future<void> _reject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفض طلب الربط'),
        content: const Text('سيتم رفض طلب ربط الشقة ولن يتم تفعيل العقد.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('رفض', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => ref.read(repositoryProvider).rejectLease(widget.lease), 'تم رفض طلب الربط');
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(managerSnapshotProvider);
      ref.invalidate(ownerSnapshotProvider);
      ref.invalidate(vacantPortfolioProvider);
      ref.invalidate(tenantSnapshotProvider);
      widget.onChanged?.call();
      if (mounted) showSuccess(context, success);
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lease = widget.lease;
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: AppColors.pending.withValues(alpha: .30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.pending.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.assignment_ind_rounded, color: AppColors.pending, size: 21),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lease.tenantName ?? 'مستأجر جديد',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      lease.apartmentLabel ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const StatusPill(label: 'طلب ربط', color: AppColors.pending, compact: true),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _LeaseMetric(
                  label: 'الإيجار',
                  value: formatMoney(lease.monthlyRent, compact: true),
                  color: AppColors.gold,
                ),
              ),
              Expanded(
                child: _LeaseMetric(
                  label: 'البداية',
                  value: formatDate(lease.startDate),
                ),
              ),
              Expanded(
                child: _LeaseMetric(
                  label: 'النهاية',
                  value: formatDate(lease.endDate),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: SoftButton(
                  label: 'رفض',
                  icon: Icons.close_rounded,
                  color: AppColors.danger,
                  height: 42,
                  onPressed: _busy ? null : _reject,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: GoldButton(
                  label: 'موافقة وتفعيل العقد',
                  icon: Icons.check_circle_rounded,
                  height: 42,
                  loading: _busy,
                  onPressed: _approve,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaseMetric extends StatelessWidget {
  const _LeaseMetric({required this.label, required this.value, this.color = AppColors.textPrimary});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.w800, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 8, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
