import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/system_insets.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../core/i18n/i18n.dart';

Future<bool> showVacateTenantSheet({
  required BuildContext context,
  required SupabaseRepository repository,
  required TenantRecord tenant,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _VacateTenantSheet(repository: repository, tenant: tenant),
  );
  return saved == true;
}

class _VacateTenantSheet extends StatefulWidget {
  const _VacateTenantSheet({required this.repository, required this.tenant});

  final SupabaseRepository repository;
  final TenantRecord tenant;

  @override
  State<_VacateTenantSheet> createState() => _VacateTenantSheetState();
}

class _VacateTenantSheetState extends State<_VacateTenantSheet> {
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.vacateTenant(
        tenantId: widget.tenant.profile.id,
        apartmentId: widget.tenant.apartment.id,
        moveOutDate: _date,
        notes: _notes.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = friendlyError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.navy800,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        padding: withSystemBottomInset(context, const EdgeInsets.all(AppSpacing.lg)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.logout_rounded, color: AppColors.danger),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text(
                      'إخلاء الشقة وأرشفة المستأجر',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textMuted),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.pending.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                      color: AppColors.pending.withValues(alpha: .35)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: AppColors.pending),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'سيتم إنهاء ربط المستأجر بالشقة وتحويل حالتها إلى «فارغة» فوراً. '
                        'تبقى بيانات المستأجر والعقد والدفعات والمستمسكات محفوظة في الأرشيف ولا تُحذف.',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 10.5,
                          height: 1.6,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              InfoRow(
                icon: Icons.person_rounded,
                label: 'المستأجر',
                value: widget.tenant.profile.displayName,
              ),
              InfoRow(
                icon: Icons.apartment_rounded,
                label: 'الشقة',
                value: widget.tenant.apartment.label,
              ),
              if (widget.tenant.lease != null)
                InfoRow(
                  icon: Icons.event_busy_rounded,
                  label: 'نهاية العقد الحالي',
                  value: formatDate(widget.tenant.lease!.endDate),
                ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: tr('تاريخ الإخلاء'),
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  child: Text(
                    formatDate(_date),
                    style: const TextStyle(
                        fontFamily: 'Tajawal', color: AppColors.textPrimary),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _notes,
                maxLines: 2,
                style: const TextStyle(
                    fontFamily: 'Tajawal', color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: tr('سبب الإخلاء أو ملاحظات (اختياري)'),
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    color: AppColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(
                    _loading ? 'جارٍ الإخلاء...' : 'تأكيد إخلاء الشقة',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Center(
                child: TextButton(
                  onPressed: _loading ? null : () => Navigator.pop(context),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
