import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/i18n/app_country.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/language_toggle.dart';
import '../../core/widgets/otp_field.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';

enum _AuthMode { login, signup }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _inviteController = TextEditingController();
  final _otpController = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  UserRole _role = UserRole.tenant;
  AppCountry _country = AppCountry.iq;
  bool _otpStep = false;
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  int _resendSeconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _inviteController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _switchMode(_AuthMode mode) {
    if (_loading) return;
    setState(() {
      _mode = mode;
      _otpStep = false;
      _error = null;
      _otpController.clear();
    });
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).signIn(
            phone: _phoneController.text,
            password: _passwordController.text,
            country: _country,
          );
      ref.invalidate(currentProfileProvider);
      if (mounted) showSuccess(context, 'تم تسجيل الدخول');
    } catch (error) {
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signUp() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(authServiceProvider).signUp(
            fullName: _nameController.text,
            phone: _phoneController.text,
            password: _passwordController.text,
            role: _role,
            inviteCode: _inviteController.text,
            country: _country,
          );
      if (response.session != null) {
        if (_role != UserRole.tenant) {
          await ref
              .read(repositoryProvider)
              .claimRole(_role, _inviteController.text.trim());
        }
        ref.invalidate(currentProfileProvider);
        if (mounted) showSuccess(context, 'تم إنشاء حسابك بنجاح');
        return;
      }
      setState(() {
        _otpStep = true;
        _otpController.clear();
      });
      _startTimer();
      if (mounted) showSuccess(context, 'أرسلنا رمز التحقق إلى هاتفك');
    } catch (error) {
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    FocusScope.of(context).unfocus();
    final code = _otpController.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'أدخل رمز التحقق المكوّن من 6 أرقام');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).verifySignupOtp(
            phone: _phoneController.text,
            code: code,
            role: _role,
            inviteCode: _inviteController.text,
            country: _country,
          );
      ref.invalidate(currentProfileProvider);
      if (mounted) showSuccess(context, 'تم تفعيل حسابك بنجاح');
    } catch (error) {
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .resendSignupOtp(_phoneController.text, country: _country);
      _startTimer();
      if (mounted) showSuccess(context, 'تم إرسال رمز جديد');
    } catch (error) {
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendSeconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: PremiumBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  children: [
                    const Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: LanguageToggle(),
                    ),
                    _buildBrand(),
                    const SizedBox(height: AppSpacing.xl),
                    GlassCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      glowColor: AppColors.gold,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        child: _otpStep
                            ? _buildOtpStep()
                            : _mode == _AuthMode.login
                                ? _buildLoginStep()
                                : _buildSignupStep(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'بالدخول أنت توافق على سياسة الخصوصية وشروط الاستخدام',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 10,
                        color: AppColors.textMuted.withValues(alpha: .9),
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

  Widget _buildBrand() {
    return Column(
      children: [
        const BrandLogo(width: 148, padding: 12, radius: 26)
            .animate()
            .fadeIn(duration: 450.ms)
            .scale(begin: const Offset(.85, .85), curve: Curves.easeOutBack),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'The City Property',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 27,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: .3,
          ),
        ).animate().fadeIn(delay: 120.ms, duration: 450.ms).slideY(begin: .2, end: 0),
        const SizedBox(height: 4),
        const Text(
          'نظام إدارة الأملاك المتكامل',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ).animate().fadeIn(delay: 220.ms, duration: 450.ms),
      ],
    );
  }

  Widget _buildLoginStep() {
    return Column(
      key: const ValueKey('login'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'تسجيل الدخول',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'أدخل رقم هاتفك وكلمة المرور',
          style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildPhoneField(),
        const SizedBox(height: AppSpacing.md),
        _buildPasswordField(onSubmitted: (_) => _login()),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          _ErrorBanner(message: _error!),
        ],
        const SizedBox(height: AppSpacing.lg),
        GoldButton(
          label: 'دخول',
          icon: Icons.login_rounded,
          loading: _loading,
          onPressed: _login,
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: TextButton(
            onPressed: _loading ? null : () => _switchMode(_AuthMode.signup),
            child: const Text(
              'ليس لديك حساب؟ إنشاء حساب جديد',
              style: TextStyle(fontFamily: 'Tajawal', color: AppColors.gold),
            ),
          ),
        ),
        const Row(
          children: [
            Icon(Icons.shield_rounded, size: 15, color: AppColors.occupied),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'دخول محمي برقم الهاتف وكلمة المرور',
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignupStep() {
    return Column(
      key: const ValueKey('signup'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إنشاء حساب',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'سيتم إرسال رمز تحقق إلى هاتفك لتفعيل الحساب',
          style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _nameController,
          textInputAction: TextInputAction.next,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: tr('الاسم الكامل'),
            prefixIcon: Icon(Icons.badge_rounded),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildPhoneField(),
        const SizedBox(height: AppSpacing.md),
        _buildPasswordField(
          hint: 'كلمة المرور (8 أحرف على الأقل)',
          onSubmitted: (_) => _signUp(),
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
        SegmentedButton<UserRole>(
          segments: const [
            ButtonSegment(value: UserRole.tenant, label: Text('مستأجر'), icon: Icon(Icons.person_rounded)),
            ButtonSegment(value: UserRole.owner, label: Text('مالك'), icon: Icon(Icons.villa_rounded)),
            ButtonSegment(value: UserRole.manager, label: Text('مدير'), icon: Icon(Icons.badge_rounded)),
          ],
          selected: {_role},
          showSelectedIcon: false,
          onSelectionChanged: _loading
              ? null
              : (values) => setState(() {
                    _role = values.first;
                    _error = null;
                  }),
          style: SegmentedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            selectedForegroundColor: AppColors.navy900,
            selectedBackgroundColor: AppColors.gold,
            textStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        if (_role != UserRole.tenant) ...[
          const SizedBox(height: AppSpacing.md),
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
            decoration: InputDecoration(
              hintText: tr('رمز الدعوة'),
              prefixIcon: Icon(Icons.vpn_key_rounded),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          _ErrorBanner(message: _error!),
        ],
        const SizedBox(height: AppSpacing.lg),
        GoldButton(
          label: 'إنشاء الحساب',
          icon: Icons.person_add_alt_1_rounded,
          loading: _loading,
          onPressed: _signUp,
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: TextButton(
            onPressed: _loading ? null : () => _switchMode(_AuthMode.login),
            child: const Text(
              'لديك حساب؟ تسجيل الدخول',
              style: TextStyle(fontFamily: 'Tajawal', color: AppColors.gold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PopupMenuButton<AppCountry>(
          tooltip: tr('الدولة'),
          initialValue: _country,
          onSelected: (country) => setState(() {
            _country = country;
            _error = null;
          }),
          itemBuilder: (context) => AppCountry.values
              .map((country) => PopupMenuItem<AppCountry>(
                    value: country,
                    child: Row(
                      children: [
                        Text(country.flag, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${country.name(english: I18n.isEnglish)} · ${country.dialCode}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.navy700.withValues(alpha: .65),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
            ),
            child: Row(
              children: [
                Text(_country.flag, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 6),
                Text(
                  _country.dialCode,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_drop_down_rounded,
                    size: 18, color: AppColors.gold),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_country.phoneLength),
            ],
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 16,
              letterSpacing: 1,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: _country.phoneHint,
              prefixIcon: const Icon(Icons.phone_iphone_rounded),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    String hint = 'كلمة المرور',
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: _passwordController,
      obscureText: _obscure,
      textInputAction: TextInputAction.done,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        fontFamily: 'Tajawal',
        fontSize: 16,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.lock_rounded),
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

  Widget _buildOtpStep() {
    final phone =
        _country.prettyPhone(_country.normalizePhone(_phoneController.text));
    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _loading
                  ? null
                  : () => setState(() {
                        _otpStep = false;
                        _error = null;
                      }),
              icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'رمز التحقق',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'أرسلنا رمزاً مكوّناً من 6 أرقام إلى $phone',
          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        OtpField(
          controller: _otpController,
          onCompleted: (_) => _verifyOtp(),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          _ErrorBanner(message: _error!),
        ],
        const SizedBox(height: AppSpacing.lg),
        GoldButton(
          label: 'تحقق وتفعيل الحساب',
          icon: Icons.verified_rounded,
          loading: _loading,
          onPressed: _verifyOtp,
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: TextButton(
            onPressed: _loading || _resendSeconds > 0 ? null : _resendOtp,
            child: Text(
              _resendSeconds > 0 ? 'إعادة الإرسال بعد $_resendSeconds ثانية' : 'إعادة إرسال الرمز',
              style: TextStyle(
                fontFamily: 'Tajawal',
                color: _resendSeconds > 0 ? AppColors.textMuted : AppColors.gold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.danger.withValues(alpha: .35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11,
                height: 1.5,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
