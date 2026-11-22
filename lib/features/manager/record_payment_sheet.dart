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

/// يسجل الدفعة على فاتورة الشهر إن وُجدت حتى يبقى سجل الفواتير متطابقاً،
/// وإلا يضيفها كدفعة مستقلة على المستأجر.
Future<bool> showRecordPaymentSheet({
  required BuildContext context,
  required SupabaseRepository repository,
  required TenantRecord tenant,
  required double expected,
  Invoice? invoice,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RecordPaymentSheet(
      repository: repository,
      tenant: tenant,
      expected: expected,
      invoice: invoice,
    ),
  );
  return saved == true;
}

class _RecordPaymentSheet extends StatefulWidget {
  const _RecordPaymentSheet({
    required this.repository,
    required this.tenant,
    required this.expected,
    this.invoice,
  });

  final SupabaseRepository repository;
  final TenantRecord tenant;
  final double expected;
  final Invoice? invoice;

  @override
  State<_RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<_RecordPaymentSheet> {
  late final TextEditingController _amount = TextEditingController(
    text: _defaultAmount.toStringAsFixed(0),
  );
  final _receipt = TextEditingController();
  final _notes = TextEditingController();
  String _method = 'cash';
  DateTime _date = DateTime.now();
  bool _loading = false;
  String? _error;

  double get _defaultAmount {
    final invoice = widget.invoice;
    if (invoice != null && invoice.remaining > 0) return invoice.remaining;
    return widget.expected;
  }

  @override
  void dispose() {
    _amount.dispose();
    _receipt.dispose();
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
    final amount =
        double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'أدخل مبلغاً صحيحاً');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final receipt = _receipt.text.trim();
    final notes = _notes.text.trim();
    final invoice = widget.invoice;
    try {
      if (invoice != null) {
        final merged = [
          if (receipt.isNotEmpty) 'رقم الوصل: $receipt',
          if (notes.isNotEmpty) notes,
        ].join(' · ');
        await widget.repository.recordInvoicePayment(
          invoiceId: invoice.id,
          amount: amount,
          method: _method,
          date: _date,
          notes: merged,
        );
      } else {
        await widget.repository.recordPayment(
          tenantId: widget.tenant.profile.id,
          amount: amount,
          method: _method,
          date: _date,
          receiptNumber: receipt,
          notes: notes,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyError(error);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final invoice = widget.invoice;
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
                  const Icon(Icons.receipt_long_rounded,
                      color: AppColors.occupied),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'تسجيل دفعة — ${widget.tenant.profile.displayName}',
                      style: const TextStyle(
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
              InfoRow(
                icon: Icons.domain_rounded,
                label: 'الشقة',
                value: widget.tenant.apartment.label,
              ),
              InfoRow(
                icon: Icons.payments_rounded,
                label: 'الإيجار الشهري',
                value: formatMoney(widget.expected, withCurrency: true),
                valueColor: AppColors.gold,
              ),
              if (invoice != null)
                InfoRow(
                  icon: Icons.description_rounded,
                  label: 'فاتورة ${invoice.number}',
                  value:
                      '${formatMoney(invoice.remaining, withCurrency: true)} متبقٍ',
                  valueColor: AppColors.pending,
                ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                    fontFamily: 'Tajawal', color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: tr('المبلغ المستلم'),
                  prefixIcon: Icon(Icons.payments_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final entry in const [
                    ('cash', 'نقداً'),
                    ('transfer', 'تحويل'),
                    ('cheque', 'صك'),
                  ])
                    ChoiceChip(
                      label: Text(
                        entry.$2,
                        style: const TextStyle(fontFamily: 'Tajawal'),
                      ),
                      selected: _method == entry.$1,
                      selectedColor: AppColors.occupied.withValues(alpha: .22),
                      onSelected: (_) => setState(() => _method = entry.$1),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: tr('تاريخ الدفعة'),
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
                controller: _receipt,
                style: const TextStyle(
                    fontFamily: 'Tajawal', color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: tr('رقم الوصل (اختياري)'),
                  prefixIcon: Icon(Icons.confirmation_number_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _notes,
                maxLines: 2,
                style: const TextStyle(
                    fontFamily: 'Tajawal', color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: tr('ملاحظات (اختياري)'),
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
              GoldButton(
                label: 'حفظ الدفعة',
                icon: Icons.check_circle_rounded,
                loading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
