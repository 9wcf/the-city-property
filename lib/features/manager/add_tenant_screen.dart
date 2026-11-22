import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/providers.dart';
import '../../core/i18n/app_country.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_utils.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';
import '../../core/i18n/i18n.dart';

class AddTenantScreen extends ConsumerStatefulWidget {
  const AddTenantScreen({
    super.key,
    required this.manager,
    this.portfolio,
    this.initialApartment,
  });

  final AppProfile manager;
  final Portfolio? portfolio;
  final Apartment? initialApartment;

  @override
  ConsumerState<AddTenantScreen> createState() => _AddTenantScreenState();
}

class _AddTenantScreenState extends ConsumerState<AddTenantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rentController = TextEditingController();
  final _depositController = TextEditingController();
  final _notesController = TextEditingController();

  static const int _maxDocumentsPerKind = 12;

  final List<XFile> _tenantDocuments = [];
  final List<XFile> _contractImages = [];

  Portfolio? _portfolio;
  String? _compoundId;
  String? _buildingId;
  String? _floorId;
  Apartment? _apartment;
  DateTime _startDate = DateTime.now();
  int _months = 12;
  bool _loading = false;
  bool _loadingPortfolio = true;
  bool _obscurePassword = true;
  String? _error;

  AppCountry get _country => _apartment?.country ?? AppCountry.iq;

  @override
  void initState() {
    super.initState();
    _portfolio = widget.portfolio;
    _apartment = widget.initialApartment;
    if (_apartment != null) {
      _rentController.text = _apartment!.rentAmount.toStringAsFixed(0);
    }
    if (_portfolio == null) {
      _loadPortfolio();
    } else {
      _loadingPortfolio = false;
    }
  }

  Future<void> _loadPortfolio() async {
    try {
      final portfolio = await ref
          .read(repositoryProvider)
          .managerPortfolio(widget.manager.id);
      if (!mounted) return;
      setState(() {
        _portfolio = portfolio;
        _loadingPortfolio = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(error);
        _loadingPortfolio = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _rentController.dispose();
    _depositController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<Compound> get _compounds => _portfolio?.compounds ?? const [];
  Compound? get _compound =>
      _compounds.where((c) => c.id == _compoundId).firstOrNull;
  Building? get _building =>
      _compound?.buildings.where((b) => b.id == _buildingId).firstOrNull;
  Floor? get _floor =>
      _building?.floors.where((f) => f.id == _floorId).firstOrNull;
  String _floorTitle(Floor floor) {
    for (final apartment in floor.apartments) {
      final custom = apartment.floorLabelText?.trim();
      if (custom != null && custom.isNotEmpty) return custom;
    }
    return 'طابق ${floor.floorNumber}';
  }
  List<Apartment> get _vacantApartments => (_floor?.apartments ?? const [])
      .where((a) => a.status == ApartmentStatus.vacant)
      .toList();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: Locale(I18n.language.name),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickImages({
    required bool contract,
    required bool fromCamera,
  }) async {
    final target = contract ? _contractImages : _tenantDocuments;
    final remaining = _maxDocumentsPerKind - target.length;
    if (remaining <= 0) {
      showError(context, 'الحد الأقصى $_maxDocumentsPerKind صورة لكل قسم');
      return;
    }
    try {
      final picker = ImagePicker();
      final List<XFile> picked;
      if (fromCamera) {
        final image = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 2400,
        );
        picked = image == null ? const [] : [image];
      } else {
        picked = await picker.pickMultiImage(
          imageQuality: 85,
          maxWidth: 2400,
        );
      }
      if (picked.isEmpty || !mounted) return;
      setState(() {
        target.addAll(picked.take(remaining));
      });
      if (picked.length > remaining) {
        showError(context, 'تمت إضافة أول $remaining صورة فقط');
      }
    } catch (error) {
      if (mounted) {
        showError(context, 'تعذر اختيار الصور: ${friendlyError(error)}');
      }
    }
  }

  void _removeImage({required bool contract, required XFile file}) {
    setState(() {
      (contract ? _contractImages : _tenantDocuments).remove(file);
    });
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final apartment = _apartment;
    if (apartment == null) {
      setState(() => _error = 'اختر الشقة أولاً');
      return;
    }
    if (!_country.isValidPhone(_phoneController.text)) {
      setState(() =>
          _error = 'أدخل رقماً صحيحاً لـ${_country.nameAr} (${_country.phoneHint})');
      return;
    }
    if (_passwordController.text.trim().length < 8) {
      setState(() => _error = 'كلمة المرور المؤقتة يجب أن تكون 8 أحرف على الأقل');
      return;
    }
    final rent = double.tryParse(_rentController.text.replaceAll(',', ''));
    if (rent == null || rent <= 0) {
      setState(() => _error = 'أدخل مبلغ إيجار صحيح');
      return;
    }

    setState(() => _loading = true);
    try {
      final repo = ref.read(repositoryProvider);
      final endDate = addMonthsClamped(_startDate, _months);
      final created = await repo.managerAddTenant(
        managerId: widget.manager.id,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        apartment: apartment,
        monthlyRent: rent,
        startDate: _startDate,
        endDate: endDate,
        deposit:
            double.tryParse(_depositController.text.replaceAll(',', '')) ?? 0,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        password: _passwordController.text.trim(),
      );

      var uploaded = 0;
      var failed = 0;
      Future<void> uploadDocs(String kind, List<XFile> files) async {
        if (files.isEmpty) return;
        try {
          final result = await repo.uploadLeaseDocuments(
            leaseId: created.leaseId,
            tenantId: created.tenantId,
            apartmentId: apartment.id,
            kind: kind,
            files: List<XFile>.of(files),
          );
          uploaded += result.uploaded;
          failed += result.failed;
        } catch (_) {
          failed += files.length;
        }
      }

      await uploadDocs('tenant', _tenantDocuments);
      await uploadDocs('contract', _contractImages);

      ref.invalidate(managerSnapshotProvider);
      ref.invalidate(ownerSnapshotProvider);
      if (mounted) {
        if (failed > 0) {
          showError(
            context,
            'تم إضافة المستأجر، لكن تعذر رفع $failed صورة. يمكنك إضافتها لاحقاً من بطاقة المستأجر.',
          );
        } else if (uploaded > 0) {
          showSuccess(context, 'تم إضافة المستأجر ورفع $uploaded صورة بنجاح');
        } else {
          showSuccess(context, 'تم إضافة المستأجر وتفعيل الشقة بنجاح');
        }
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'إضافة مستأجر',
      body: _loadingPortfolio
          ? const Center(child: CircularProgressIndicator())
          : _compounds.isEmpty
              ? EmptyState(
                  icon: Icons.business_outlined,
                  title: 'لا توجد عقارات موكلة إليك',
                  message: _error,
                  actionLabel: 'إعادة المحاولة',
                  onAction: _loadPortfolio,
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                    children: [
                      const SectionHeader(
                        title: 'معلومات المستأجر',
                        subtitle:
                            'ينشئ النظام حساب دخول للمستأجر بهاتفه وكلمة المرور المؤقتة',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      GlassCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                labelText: tr('الاسم الكامل'),
                                prefixIcon: Icon(Icons.person_rounded),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().length < 3
                                      ? tr('أدخل الاسم الكامل')
                                      : null,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(15),
                              ],
                              style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                labelText: tr('رقم الهاتف'),
                                hintText: _country.phoneHint,
                                prefixIcon:
                                    const Icon(Icons.phone_iphone_rounded),
                              ),
                              validator: (value) => _country
                                      .isValidPhone(value ?? '')
                                  ? null
                                  : tr('رقم غير صالح لـ${_country.nameAr} (${_country.phoneHint})'),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                labelText: tr('كلمة المرور المؤقتة'),
                                helperText: tr('٨ أحرف على الأقل · شاركها مع المستأجر'),
                                prefixIcon:
                                    const Icon(Icons.lock_rounded),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'إظهار'
                                      : 'إخفاء',
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                  ),
                                ),
                              ),
                              validator: (value) =>
                                  (value ?? '').trim().length < 8
                                      ? tr('كلمة المرور 8 أحرف على الأقل')
                                      : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const SectionHeader(
                        title: 'الشقة والعقد',
                        subtitle: 'اختر شقة فارغة وحدد شروط الإيجار',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      GlassCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          children: [
                            if (widget.initialApartment != null)
                              _buildSelectedApartment()
                            else ...[
                              _DropdownField(
                                label: 'العقار',
                                icon: Icons.location_city_rounded,
                                value: _compoundId,
                                items: _compounds
                                    .map((c) => DropdownMenuItem(
                                        value: c.id, child: Text(c.name)))
                                    .toList(),
                                onChanged: (value) => setState(() {
                                  _compoundId = value;
                                  _buildingId = null;
                                  _floorId = null;
                                  _apartment = null;
                                }),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _DropdownField(
                                label: 'العمارة',
                                icon: Icons.apartment_rounded,
                                value: _buildingId,
                                items: (_compound?.buildings ?? [])
                                    .map((b) => DropdownMenuItem(
                                        value: b.id, child: Text(b.name)))
                                    .toList(),
                                onChanged: (value) => setState(() {
                                  _buildingId = value;
                                  _floorId = null;
                                  _apartment = null;
                                }),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _DropdownField(
                                label: 'الطابق',
                                icon: Icons.layers_rounded,
                                value: _floorId,
                                items: (_building?.floors ?? [])
                                    .map((f) => DropdownMenuItem(
                                        value: f.id,
                                        child: Text(_floorTitle(f))))
                                    .toList(),
                                onChanged: (value) => setState(() {
                                  _floorId = value;
                                  _apartment = null;
                                }),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _DropdownField(
                                label: 'الشقة الفارغة',
                                icon: Icons.meeting_room_rounded,
                                value: _apartment?.id,
                                items: _vacantApartments
                                    .map((a) => DropdownMenuItem(
                                          value: a.id,
                                          child: Text(
                                              '${a.displayName} · ${formatMoney(a.rentAmount, compact: true)}'),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  final apartment = _vacantApartments
                                      .where((a) => a.id == value)
                                      .firstOrNull;
                                  setState(() => _apartment = apartment);
                                  if (apartment != null) {
                                    _rentController.text =
                                        apartment.rentAmount.toStringAsFixed(0);
                                  }
                                },
                              ),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _rentController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    style: const TextStyle(
                                        fontFamily: 'Tajawal',
                                        color: AppColors.textPrimary),
                                    decoration: InputDecoration(
                                      labelText: I18n.isEnglish
                                          ? 'Monthly rent (${_country.currencyCode})'
                                          : 'الإيجار الشهري (${_country.currencyCode})',
                                      prefixIcon: Icon(Icons.payments_rounded),
                                    ),
                                    validator: (value) =>
                                        double.tryParse(value ?? '') == null
                                            ? tr('أدخل المبلغ')
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: TextFormField(
                                    controller: _depositController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    style: const TextStyle(
                                        fontFamily: 'Tajawal',
                                        color: AppColors.textPrimary),
                                    decoration: InputDecoration(
                                      labelText: tr('التأمين (اختياري)'),
                                      prefixIcon: Icon(Icons.savings_rounded),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.navy700.withValues(alpha: .65),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: .08)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_month_rounded,
                                        color: AppColors.gold, size: 20),
                                    const SizedBox(width: AppSpacing.sm),
                                    const Text(
                                      'تاريخ بداية العقد',
                                      style: TextStyle(
                                          fontFamily: 'Tajawal',
                                          fontSize: 12,
                                          color: AppColors.textSecondary),
                                    ),
                                    const Spacer(),
                                    Text(
                                      formatDate(_startDate),
                                      style: const TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                const Text(
                                  'مدة العقد',
                                  style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Wrap(
                                    alignment: WrapAlignment.end,
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [1, 3, 6, 12].map(
                                      (months) => ChoiceChip(
                                        label: Text(leaseDurationLabel(months)),
                                        selected: _months == months,
                                        onSelected: (_) =>
                                            setState(() => _months = months),
                                        selectedColor: AppColors.gold,
                                        backgroundColor:
                                            Colors.white.withValues(alpha: .04),
                                        labelStyle: TextStyle(
                                          fontFamily: 'Tajawal',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _months == months
                                              ? AppColors.navy900
                                              : AppColors.textSecondary,
                                        ),
                                        side: BorderSide(
                                          color: _months == months
                                              ? AppColors.gold
                                              : Colors.white
                                                  .withValues(alpha: .08),
                                        ),
                                      ),
                                    ).toList(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _notesController,
                              maxLines: 2,
                              style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                labelText: tr('ملاحظات (اختياري)'),
                                prefixIcon: Icon(Icons.notes_rounded),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const SectionHeader(
                        title: 'المستمسكات وصور العقد',
                        subtitle:
                            'ارفع صور مستمسكات المستأجر وصور عقد الإيجار (اختياري)',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      GlassCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          children: [
                            _DocumentsPickerField(
                              title: 'مستمسكات المستأجر',
                              hint: 'الهوية، بطاقة السكن، أو أي مستمسك رسمي',
                              icon: Icons.badge_rounded,
                              files: _tenantDocuments,
                              maxFiles: _maxDocumentsPerKind,
                              onPick: (fromCamera) => _pickImages(
                                contract: false,
                                fromCamera: fromCamera,
                              ),
                              onRemove: (file) =>
                                  _removeImage(contract: false, file: file),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _DocumentsPickerField(
                              title: 'صور عقد الإيجار',
                              hint: 'صور صفحات العقد الموقّع',
                              icon: Icons.description_rounded,
                              files: _contractImages,
                              maxFiles: _maxDocumentsPerKind,
                              onPick: (fromCamera) => _pickImages(
                                contract: true,
                                fromCamera: fromCamera,
                              ),
                              onRemove: (file) =>
                                  _removeImage(contract: true, file: file),
                            ),
                          ],
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                                color: AppColors.danger.withValues(alpha: .35)),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11,
                              height: 1.5,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      GoldButton(
                        label: 'إضافة المستأجر وتفعيل الشقة',
                        icon: Icons.check_circle_rounded,
                        loading: _loading,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSelectedApartment() {
    final apartment = widget.initialApartment!;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.occupied.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.occupied.withValues(alpha: .30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.meeting_room_rounded,
              color: AppColors.occupied, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              [
                apartment.displayName,
                if (apartment.floorLabel.isNotEmpty) apartment.floorLabel,
                if ((apartment.buildingName ?? '').isNotEmpty)
                  apartment.buildingName!,
              ].join(' · '),
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const StatusPill(
              label: 'فارغة', color: AppColors.occupied, compact: true),
        ],
      ),
    );
  }
}

class _DocumentsPickerField extends StatelessWidget {
  const _DocumentsPickerField({
    required this.title,
    required this.hint,
    required this.icon,
    required this.files,
    required this.maxFiles,
    required this.onPick,
    required this.onRemove,
  });

  final String title;
  final String hint;
  final IconData icon;
  final List<XFile> files;
  final int maxFiles;
  final ValueChanged<bool> onPick;
  final ValueChanged<XFile> onRemove;

  @override
  Widget build(BuildContext context) {
    final canAdd = files.length < maxFiles;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.navy700.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.gold, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      hint,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: '${files.length}/$maxFiles',
                color: files.isEmpty ? AppColors.textMuted : AppColors.occupied,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canAdd ? () => onPick(false) : null,
                  icon: const Icon(Icons.photo_library_rounded, size: 16),
                  label: const Text('من المعرض'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: BorderSide(
                      color: AppColors.gold.withValues(alpha: .35),
                    ),
                  ),
                ),
              ),
              if (!kIsWeb) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canAdd ? () => onPick(true) : null,
                    icon: const Icon(Icons.photo_camera_rounded, size: 16),
                    label: const Text('بالكاميرا'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: .12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (files.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: files
                  .map(
                    (file) => _LocalImageThumb(
                      file: file,
                      onRemove: () => onRemove(file),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _LocalImageThumb extends StatefulWidget {
  const _LocalImageThumb({required this.file, required this.onRemove});

  final XFile file;
  final VoidCallback onRemove;

  @override
  State<_LocalImageThumb> createState() => _LocalImageThumbState();
}

class _LocalImageThumbState extends State<_LocalImageThumb> {
  late final Future<Uint8List> _bytes = widget.file.readAsBytes();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: FutureBuilder<Uint8List>(
                future: _bytes,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Image.memory(snapshot.data!, fit: BoxFit.cover);
                  }
                  return Container(
                    color: AppColors.navy700,
                    child: const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: -6,
            left: -6,
            child: GestureDetector(
              onTap: widget.onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      dropdownColor: AppColors.navy700,
      style: const TextStyle(
          fontFamily: 'Tajawal', fontSize: 13, color: AppColors.textPrimary),
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: items,
      onChanged: items.isEmpty ? null : onChanged,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
