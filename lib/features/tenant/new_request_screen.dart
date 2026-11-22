import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';
import '../../core/i18n/i18n.dart';

class NewRequestScreen extends ConsumerStatefulWidget {
  const NewRequestScreen({
    super.key,
    required this.tenant,
    required this.apartment,
  });

  final AppProfile tenant;
  final Apartment apartment;

  @override
  ConsumerState<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends ConsumerState<NewRequestScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();

  String _category = 'plumbing';
  String _priority = 'normal';
  final List<XFile> _images = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = 4 - _images.length;
    if (remaining <= 0) return;
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 78);
      if (picked.isEmpty) return;
      setState(() {
        _images.addAll(picked.take(remaining));
      });
    } catch (error) {
      if (mounted) showError(context, 'تعذر اختيار الصور: ${friendlyError(error)}');
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.length < 3) {
      setState(() => _error = 'اكتب عنواناً واضحاً للمشكلة');
      return;
    }
    if (description.length < 5) {
      setState(() => _error = 'أضف وصفاً كافياً للمشكلة');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(repositoryProvider).createRequest(
            apartmentId: widget.apartment.id,
            tenantId: widget.tenant.id,
            category: _category,
            title: title,
            description: description,
            priority: _priority,
            images: _images,
          );
      ref.invalidate(tenantSnapshotProvider);
      ref.invalidate(managerSnapshotProvider);
      ref.invalidate(ownerSnapshotProvider);
      if (mounted) {
        showSuccess(context, 'تم إرسال طلب الصيانة إلى مدير العقارات');
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
      title: 'طلب خدمة جديدة',
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.meeting_room_rounded, color: AppColors.gold, size: 21),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.apartment.label,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        [
                          if (widget.apartment.compoundName != null) widget.apartment.compoundName!,
                          if (widget.apartment.floorLabel.isNotEmpty) widget.apartment.floorLabel,
                        ].join(' · '),
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const StatusPill(label: 'مؤجرة', color: AppColors.occupied, compact: true),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'نوع الخدمة', subtitle: 'اختر التصنيف الأقرب للمشكلة'),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: maintenanceCategories.entries.map((entry) {
              final active = _category == entry.key;
              return GestureDetector(
                onTap: () => setState(() => _category = entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? AppColors.gold : Colors.white.withValues(alpha: .04),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: active ? AppColors.gold : Colors.white.withValues(alpha: .09),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        maintenanceCategoryIcons[entry.key] ?? Icons.handyman_rounded,
                        size: 15,
                        color: active ? AppColors.navy900 : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        entry.value,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                          color: active ? AppColors.navy900 : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: tr('عنوان الطلب'),
                    hintText: tr('مثال: تسريب ماء في حمام الشقة'),
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _descriptionController,
                  maxLines: 4,
                  style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: tr('وصف المشكلة'),
                    hintText: tr('اشرح المشكلة ومتى بدأت وأي تفاصيل تساعد الفني…'),
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'درجة الأولوية',
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _PriorityChip(label: 'منخفضة', value: 'low', selected: _priority == 'low', color: AppColors.info, onTap: () => setState(() => _priority = 'low')),
                    const SizedBox(width: AppSpacing.sm),
                    _PriorityChip(label: 'متوسطة', value: 'normal', selected: _priority == 'normal', color: AppColors.pending, onTap: () => setState(() => _priority = 'normal')),
                    const SizedBox(width: AppSpacing.sm),
                    _PriorityChip(label: 'عاجلة', value: 'emergency', selected: _priority == 'emergency', color: AppColors.danger, onTap: () => setState(() => _priority = 'emergency')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'صور المشكلة', subtitle: 'حتى 4 صور — تساعد الفني على التقييم'),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                if (_images.isNotEmpty)
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: List.generate(_images.length, (index) {
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: FutureBuilder<Uint8List>(
                              future: _images[index].readAsBytes(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return Container(
                                    width: 84,
                                    height: 84,
                                    color: AppColors.navy700,
                                    child: const Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  );
                                }
                                return Image.memory(
                                  snapshot.data!,
                                  width: 84,
                                  height: 84,
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          ),
                          Positioned(
                            top: 4,
                            left: 4,
                            child: GestureDetector(
                              onTap: () => setState(() => _images.removeAt(index)),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: AppColors.danger,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                if (_images.isNotEmpty) const SizedBox(height: AppSpacing.md),
                InkWell(
                  onTap: _loading ? null : _pickImages,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: .35),
                        style: BorderStyle.solid,
                      ),
                      color: AppColors.gold.withValues(alpha: .05),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.add_photo_alternate_rounded, color: AppColors.gold, size: 28),
                        const SizedBox(height: 6),
                        Text(
                          _images.isEmpty ? 'إضافة صور أو لقطة محادثة' : 'إضافة المزيد (${_images.length}/4)',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'صورة للمشكلة أو سكرين شوت المحادثة مع المدير',
                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 9, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
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
                border: Border.all(color: AppColors.danger.withValues(alpha: .35)),
              ),
              child: Text(
                _error!,
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, height: 1.5, color: AppColors.danger),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          GoldButton(
            label: 'إرسال الطلب',
            icon: Icons.send_rounded,
            loading: _loading,
            onPressed: _submit,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Center(
            child: Text(
              'سيتم إشعار مدير العقارات فوراً وسيتواصل معك لمتابعة الطلب.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: .18) : Colors.white.withValues(alpha: .03),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? color : Colors.white.withValues(alpha: .08),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected ? color : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
