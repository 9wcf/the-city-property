import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/config/env.dart';
import '../../core/i18n/app_country.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_utils.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    this.subtitle,
    this.extra,
  });

  final AppProfile profile;
  final String? subtitle;
  final Widget? extra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
      children: [
        const Text(
          'الملف الشخصي',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        GlassCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          glowColor: AppColors.gold,
          child: Column(
            children: [
              AppAvatar(name: profile.displayName, imageUrl: profile.avatarUrl, size: 84, showRing: true),
              const SizedBox(height: AppSpacing.md),
              Text(
                profile.displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              StatusPill(label: profile.role.label, color: AppColors.gold, icon: profile.role.icon, compact: true),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textMuted),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),
              InfoRow(icon: Icons.phone_iphone_rounded, label: 'رقم الهاتف', value: prettyPhone(profile.phoneNumber)),
              if (profile.email != null)
                InfoRow(icon: Icons.alternate_email_rounded, label: 'البريد', value: profile.email!),
              InfoRow(
                icon: Icons.verified_rounded,
                label: 'حالة الحساب',
                value: profile.isActive ? 'نشط' : 'موقوف',
                valueColor: profile.isActive ? AppColors.occupied : AppColors.danger,
              ),
              if (profile.notes != null)
                InfoRow(icon: Icons.notes_rounded, label: 'ملاحظات', value: profile.notes!),
            ],
          ),
        ),
        if (extra != null) ...[
          const SizedBox(height: AppSpacing.md),
          extra!,
        ],
        const SizedBox(height: AppSpacing.lg),
        ActionTile(
          icon: Icons.edit_rounded,
          title: 'تعديل الاسم',
          subtitle: 'تحديث بيانات ملفك الشخصي',
          onTap: () => _editName(context, ref),
        ),
        const SizedBox(height: AppSpacing.sm),
        ActionTile(
          icon: Icons.password_rounded,
          title: 'تغيير كلمة المرور',
          subtitle: 'تحديث كلمة مرور الدخول لحسابك',
          onTap: () => _changePassword(context, ref),
        ),
        if (profile.role == UserRole.tenant) ...[
          const SizedBox(height: AppSpacing.sm),
          ActionTile(
            icon: Icons.workspace_premium_rounded,
            title: 'ترقية الحساب',
            subtitle: 'تحويل الحساب إلى مالك أو مدير برمز الدعوة',
            onTap: () => _upgradeAccount(context, ref),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        ActionTile(
          icon: Icons.language_rounded,
          title: 'اللغة',
          subtitle: I18n.isEnglish ? 'English' : 'العربية',
          onTap: () => _chooseLanguage(context, ref),
        ),
        const SizedBox(height: AppSpacing.sm),
        ActionTile(
          icon: Icons.support_agent_rounded,
          title: 'الدعم والمساعدة',
          subtitle: 'تواصل مع إدارة النظام',
          onTap: () => _showAbout(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        ActionTile(
          icon: Icons.info_outline_rounded,
          title: 'حول التطبيق',
          subtitle: 'The City Property · الإصدار 1.0.0',
          onTap: () => _showAbout(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        ActionTile(
          icon: Icons.privacy_tip_outlined,
          title: 'سياسة الخصوصية',
          subtitle: 'كيف نجمع بياناتك ونحميها',
          onTap: _openPrivacyPolicy,
        ),
        const SizedBox(height: AppSpacing.sm),
        ActionTile(
          icon: Icons.delete_forever_rounded,
          title: 'حذف الحساب',
          subtitle: 'حذف نهائي لحسابك وبياناتك الشخصية',
          color: AppColors.danger,
          onTap: () => _confirmDeleteAccount(context, ref),
        ),
        const SizedBox(height: AppSpacing.lg),
        SoftButton(
          label: 'تسجيل الخروج',
          icon: Icons.logout_rounded,
          color: AppColors.danger,
          onPressed: () => _confirmSignOut(context, ref),
        ),
        const SizedBox(height: AppSpacing.md),
        const Center(
          child: Text(
            'The City Property © 2026',
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }

  Future<void> _chooseLanguage(BuildContext context, WidgetRef ref) async {
    final language = ref.read(appLanguageProvider);
    final selected = await showModalBottomSheet<AppLanguage>(
      context: context,
      backgroundColor: AppColors.navy800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.md),
            ListTile(
              leading: const Text('🇮🇶', style: TextStyle(fontSize: 20)),
              title: const Text('العربية'),
              trailing: language == AppLanguage.ar
                  ? const Icon(Icons.check_rounded, color: AppColors.gold)
                  : null,
              onTap: () => Navigator.pop(context, AppLanguage.ar),
            ),
            ListTile(
              leading: const Text('🇬🇧', style: TextStyle(fontSize: 20)),
              title: const Text('English'),
              trailing: language == AppLanguage.en
                  ? const Icon(Icons.check_rounded, color: AppColors.gold)
                  : null,
              onTap: () => Navigator.pop(context, AppLanguage.en),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
    if (selected != null) {
      await ref.read(appLanguageProvider.notifier).setLanguage(selected);
    }
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => _ChangePasswordDialog(
        phone: profile.phoneNumber,
        country: profile.country,
      ),
    );
    if (changed == true && context.mounted) {
      showSuccess(context, 'تم تغيير كلمة المرور بنجاح');
    }
  }

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: profile.fullName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل الاسم'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: tr('الاسم الكامل'),
            prefixIcon: Icon(Icons.badge_rounded),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (result == null || result.length < 3) return;
    try {
      await ref.read(repositoryProvider).updateProfile(id: profile.id, fullName: result);
      ref.invalidate(currentProfileProvider);
      if (context.mounted) showSuccess(context, 'تم تحديث الاسم');
    } catch (error) {
      if (context.mounted) showError(context, friendlyError(error));
    }
  }

  Future<void> _upgradeAccount(BuildContext context, WidgetRef ref) async {
    final inviteController = TextEditingController();
    var role = UserRole.manager;
    final result = await showDialog<({UserRole role, String invite})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('ترقية الحساب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<UserRole>(
                segments: const [
                  ButtonSegment(value: UserRole.manager, label: Text('مدير')),
                  ButtonSegment(value: UserRole.owner, label: Text('مالك')),
                ],
                selected: {role},
                onSelectionChanged: (value) =>
                    setState(() => role = value.first),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: inviteController,
                style: const TextStyle(
                    fontFamily: 'Tajawal', color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: tr('رمز الدعوة'),
                  prefixIcon: Icon(Icons.vpn_key_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء')),
            TextButton(
              onPressed: () => Navigator.pop(
                  context, (role: role, invite: inviteController.text.trim())),
              child: const Text('ترقية'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    try {
      await ref.read(repositoryProvider).claimRole(result.role, result.invite);
      ref.invalidate(currentProfileProvider);
      if (context.mounted) {
        showSuccess(context, 'تمت ترقية الحساب إلى ${result.role.label}');
      }
    } catch (error) {
      if (context.mounted) showError(context, friendlyError(error));
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DeleteAccountDialog(
        phone: profile.phoneNumber,
        country: profile.country,
        ownsCompounds: profile.role == UserRole.owner,
      ),
    );
    if (deleted != true) return;
    try {
      await ref.read(sessionControllerProvider).signOut(local: true);
    } catch (_) {
      // The login is already destroyed server-side; clearing the local
      // session is best effort.
    }
    ref.invalidate(currentProfileProvider);
  }

  Future<void> _openPrivacyPolicy() async {
    await launchUrl(
      Uri.parse('https://the-city-property.net/privacy.html'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('خروج', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(sessionControllerProvider).signOut();
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('The City Property'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نظام متكامل لإدارة العقارات السكنية: العقود، الإيجارات، الصيانة، والموافقات.',
            ),
            const SizedBox(height: AppSpacing.md),
            Text('البيئة: ${Env.appEnv}', style: const TextStyle(fontSize: 12, fontFamily: 'Tajawal')),
            Text('العملة: ${Env.currency}', style: const TextStyle(fontSize: 12, fontFamily: 'Tajawal')),
            const Text('الإصدار: 1.0.0', style: TextStyle(fontSize: 12, fontFamily: 'Tajawal')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً')),
        ],
      ),
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog({
    required this.phone,
    this.country = AppCountry.iq,
  });

  final String phone;
  final AppCountry country;

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final current = _currentController.text;
    final next = _newController.text;
    if (current.isEmpty) {
      setState(() => _error = 'أدخل كلمة المرور الحالية');
      return;
    }
    if (next.length < 8) {
      setState(() =>
          _error = 'كلمة المرور الجديدة يجب أن تكون 8 أحرف على الأقل');
      return;
    }
    if (next != _confirmController.text) {
      setState(() => _error = 'كلمتا المرور غير متطابقتين');
      return;
    }
    if (next == current) {
      setState(() => _error = 'اختر كلمة مرور مختلفة عن الحالية');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authServiceProvider);
      await auth.signIn(
        phone: widget.phone,
        password: current,
        country: widget.country,
      );
      await auth.updatePassword(next);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تغيير كلمة المرور'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _passwordField(
              _currentController,
              'كلمة المرور الحالية',
              Icons.lock_outline_rounded,
            ),
            const SizedBox(height: AppSpacing.md),
            _passwordField(
              _newController,
              'كلمة المرور الجديدة (8+)',
              Icons.lock_rounded,
            ),
            const SizedBox(height: AppSpacing.md),
            _passwordField(
              _confirmController,
              'تأكيد كلمة المرور الجديدة',
              Icons.lock_reset_rounded,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  height: 1.5,
                  color: AppColors.danger,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('تغيير'),
        ),
      ],
    );
  }

  Widget _passwordField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      obscureText: _obscure,
      enabled: !_loading,
      textInputAction: TextInputAction.next,
      style: const TextStyle(
        fontFamily: 'Tajawal',
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: IconButton(
          tooltip: _obscure ? tr('إظهار') : tr('إخفاء'),
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog({
    required this.phone,
    required this.country,
    required this.ownsCompounds,
  });

  final String phone;
  final AppCountry country;
  final bool ownsCompounds;

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _error = 'أدخل كلمة المرور الحالية');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authServiceProvider);
      await auth.signIn(
        phone: widget.phone,
        password: password,
        country: widget.country,
      );
      await ref.read(repositoryProvider).deleteMyAccount();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('حذف الحساب نهائياً؟'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'سيتم إنهاء جلستك وحذف بياناتك الشخصية: الاسم، الهاتف، الصور، '
              'المستندات، الإشعارات والرسائل. تُؤرشف وحدتك الحالية ويُنهى عقدك '
              'إن وجد، وتُحفظ السجلات المالية المطلوبة للمحاسبة بشكل مجهول الهوية.',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                height: 1.6,
                color: AppColors.textMuted,
              ),
            ),
            if (widget.ownsCompounds) ...[
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'إذا كنت مالكاً ولديك عقارات مسجلة، انقل ملكيتها أو احذفها أولاً '
                'ثم أعد المحاولة.',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                  height: 1.6,
                  color: AppColors.danger,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              enabled: !_loading,
              autofocus: true,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                labelText: tr('كلمة المرور الحالية'),
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscure ? tr('إظهار') : tr('إخفاء'),
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 20,
                  ),
                ),
              ),
              onSubmitted: (_) => _loading ? null : _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  height: 1.5,
                  color: AppColors.danger,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('حذف نهائي', style: TextStyle(color: AppColors.danger)),
        ),
      ],
    );
  }
}
