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

Future<bool> showAddExpenseSheet({
  required BuildContext context,
  required SupabaseRepository repository,
  required Portfolio portfolio,
  DateTime? initialDate,
}) async {
  final compounds = portfolio.compounds;
  if (compounds.isEmpty) return false;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddExpenseSheet(
      repository: repository,
      compounds: compounds,
      initialDate: initialDate,
    ),
  );
  return saved == true;
}

class _AddExpenseSheet extends StatefulWidget {
  const _AddExpenseSheet({
    required this.repository,
    required this.compounds,
    this.initialDate,
  });

  final SupabaseRepository repository;
  final List<Compound> compounds;
  final DateTime? initialDate;

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  static const _generalBuilding = '__general__';
  late String _compoundId = widget.compounds.first.id;
  String? _buildingId;
  String _category = 'maintenance';
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  late DateTime _date = widget.initialDate ?? DateTime.now();
  bool _loading = false;
  String? _error;

  Compound get _compound =>
      widget.compounds.firstWhere((c) => c.id == _compoundId);

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
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
    final title = _title.text.trim();
    final amount = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (title.length < 3) {
      setState(() => _error = 'أدخل بيان المصروف');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'أدخل مبلغاً صحيحاً');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.addExpense(
        compoundId: _compoundId,
        buildingId: _buildingId,
        category: _category,
        title: title,
        amount: amount,
        date: _date,
        notes: _notes.text,
      );
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
    final buildings = _compound.buildings;
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
                  const Icon(Icons.add_card_rounded, color: AppColors.gold),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text(
                      'إضافة مصروف',
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
              if (widget.compounds.length > 1)
                DropdownButtonFormField<String>(
                  initialValue: _compoundId,
                  isExpanded: true,
                  dropdownColor: AppColors.navy800,
                  style: const TextStyle(
                      fontFamily: 'Tajawal',
                      color: AppColors.textPrimary,
                      fontSize: 13),
                  decoration: InputDecoration(
                    labelText: tr('المجمع'),
                    prefixIcon: Icon(Icons.location_city_rounded),
                  ),
                  items: [
                    for (final compound in widget.compounds)
                      DropdownMenuItem(
                        value: compound.id,
                        child: Text(
                          compound.name,
                          style: const TextStyle(fontFamily: 'Tajawal'),
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _compoundId = value;
                      _buildingId = null;
                    });
                  },
                ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                key: ValueKey('building-$_compoundId'),
                initialValue: _buildingId ?? _generalBuilding,
                isExpanded: true,
                dropdownColor: AppColors.navy800,
                style: const TextStyle(
                    fontFamily: 'Tajawal',
                    color: AppColors.textPrimary,
                    fontSize: 13),
                decoration: InputDecoration(
                  labelText: tr('البناية'),
                  prefixIcon: Icon(Icons.apartment_rounded),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: _generalBuilding,
                    child: Text(
                      'عام للمجمع (غير مرتبط ببناية)',
                      style: TextStyle(fontFamily: 'Tajawal'),
                    ),
                  ),
                  for (final building in buildings)
                    DropdownMenuItem<String>(
                      value: building.id,
                      child: Text(
                        building.name,
                        style: const TextStyle(fontFamily: 'Tajawal'),
                      ),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _buildingId = value == _generalBuilding ? null : value;
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                dropdownColor: AppColors.navy800,
                style: const TextStyle(
                    fontFamily: 'Tajawal',
                    color: AppColors.textPrimary,
                    fontSize: 13),
                decoration: InputDecoration(
                  labelText: tr('نوع المصروف'),
                  prefixIcon: Icon(Icons.category_rounded),
                ),
                items: [
                  for (final entry in expenseCategories.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(
                        entry.value,
                        style: const TextStyle(fontFamily: 'Tajawal'),
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _title,
                style: const TextStyle(
                    fontFamily: 'Tajawal', color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: tr('بيان المصروف'),
                  hintText: tr('مثال: صيانة مضخة الماء'),
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                          fontFamily: 'Tajawal', color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: tr('المبلغ'),
                        prefixIcon: Icon(Icons.payments_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: tr('التاريخ'),
                          prefixIcon: Icon(Icons.calendar_today_rounded),
                        ),
                        child: Text(
                          formatDate(_date),
                          style: const TextStyle(
                              fontFamily: 'Tajawal',
                              color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                  ),
                ],
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
                      color: AppColors.danger),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              GoldButton(
                label: 'حفظ المصروف',
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
