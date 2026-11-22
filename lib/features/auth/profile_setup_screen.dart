import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_utils.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';
import '../../core/i18n/i18n.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key, this.phone});

  final String? phone;

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _inviteController = TextEditingController();
  UserRole _role = UserRole.tenant;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final name = _nameController.text.trim();
    if (name.length < 3) {
      setState(() => _error = 'أدخل الاسم الكامل (3 أحرف على الأقل)');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repository = ref.read(repositoryProvider);
      await repository.ensureProfile(name);
      if (_role != UserRole.tenant) {
        await repository.claimRole(_role, _inviteController.text.trim());
      }
      ref.invalidate(currentProfileProvider);
      if (mounted) showSuccess(context, 'تم تجهيز حسابك بنجاح');
    } catch (error) {
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = widget.phone ?? ref.read(sessionControllerProvider).session?.phone;
    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: PremiumBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.goldGradient,
                          ),
                          child: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.navy900, size: 22),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'أكمل ملفك الشخصي',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'خطوة واحدة فقط ونبدأ',
                                style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        if (phone != null)
                          StatusPill(label: prettyPhone(phone), color: AppColors.gold, compact: true),
                      ],
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: .1, end: 0),
                    const SizedBox(height: AppSpacing.xl),
                    GlassCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      glowColor: AppColors.gold,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'الاسم الكامل',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: tr('مثال: أحمد محمد'),
                              prefixIcon: Icon(Icons.badge_rounded),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          const Text(
                            'نوع الحساب',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _RoleTile(
                            role: UserRole.tenant,
                            selected: _role == UserRole.tenant,
                            title: 'مستأجر',
                            subtitle: 'إدارة إيجارك وطلبات الصيانة والتواصل',
                            onTap: () => setState(() => _role = UserRole.tenant),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _RoleTile(
                            role: UserRole.owner,
                            selected: _role == UserRole.owner,
                            title: 'مالك العقار',
                            subtitle: 'متابعة المحفظة والموافقات والإيرادات',
                            onTap: () => setState(() => _role = UserRole.owner),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _RoleTile(
                            role: UserRole.manager,
                            selected: _role == UserRole.manager,
                            title: 'مدير عقارات',
                            subtitle: 'إدارة المباني والطلبات والمستأجرين',
                            onTap: () => setState(() => _role = UserRole.manager),
                          ),
                          if (_role != UserRole.tenant) ...[
                            const SizedBox(height: AppSpacing.lg),
                            const Text(
                              'رمز الدعوة',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextField(
                              controller: _inviteController,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]'))],
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 15,
                                letterSpacing: 1.2,
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'CITY-XXXX-2026',
                                prefixIcon: Icon(Icons.vpn_key_rounded),
                              ),
                            ),
                          ],
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
                            label: 'حفظ ومتابعة',
                            icon: Icons.check_circle_rounded,
                            loading: _loading,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                    const SizedBox(height: AppSpacing.md),
                    const Center(
                      child: Text(
                        'يمكنك تغيير معلوماتك لاحقاً من صفحة الملف الشخصي',
                        style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.role,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final UserRole role;
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? AppColors.gold.withValues(alpha: .10) : Colors.white.withValues(alpha: .03),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? AppColors.gold : Colors.white.withValues(alpha: .08),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (selected ? AppColors.gold : AppColors.textMuted).withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(role.icon, color: selected ? AppColors.gold : AppColors.textMuted, size: 21),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.gold : Colors.transparent,
                  border: Border.all(
                    color: selected ? AppColors.gold : Colors.white.withValues(alpha: .18),
                  ),
                ),
                child: selected ? const Icon(Icons.check_rounded, size: 14, color: AppColors.navy900) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
