import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:the_city_property/core/theme/app_colors.dart';
import 'package:the_city_property/core/theme/app_spacing.dart';
import 'package:the_city_property/core/widgets/glass_card.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _otpSent = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final phone = _phoneController.text.trim();
      
      if (phone.isEmpty || phone.length < 10) {
        throw Exception('يرجى إدخال رقم هاتف صحيح');
      }

      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _otpSent = true;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم إرسال كود التحقق (تجريبي)'),
            backgroundColor: AppColors.occupied,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyOTP() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final otp = _otpController.text.trim();

      if (otp.isEmpty || otp.length != 6) {
        throw Exception('يرجى إدخال كود التحقق المكون من 6 أرقام');
      }

      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        context.go('/owner');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy800,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.goldGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.business,
                    size: 60,
                    color: AppColors.navy900,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                
                const Text(
                  'The City Property',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                    fontFamily: 'Tajawal',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'نظام إدارة الأملاك المتكامل',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    fontFamily: 'Tajawal',
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                GlassCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: 'Tajawal',
                        ),
                        decoration: InputDecoration(
                          labelText: 'رقم الهاتف',
                          hintText: '07701234567',
                          prefixIcon: const Icon(Icons.phone, color: AppColors.gold),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      if (_otpSent) ...[
                        TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontFamily: 'Tajawal',
                            letterSpacing: 8,
                          ),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            labelText: 'كود التحقق',
                            hintText: '------',
                            prefixIcon: const Icon(Icons.lock, color: AppColors.gold),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : (_otpSent ? _verifyOTP : _sendOTP),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: AppColors.navy900)
                              : Text(
                                  _otpSent ? 'تأكيد' : 'إرسال الكود',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Tajawal',
                                  ),
                                ),
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.vacant,
                            fontFamily: 'Tajawal',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
